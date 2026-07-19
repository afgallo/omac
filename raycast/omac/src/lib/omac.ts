// The bridge between Raycast and the omac CLI. Everything the palette knows about
// omac flows through here: where the binary lives, how to run a command and read
// its output, how to turn a "pick" source into a list of choices, and how to hand
// an interactive command off to Ghostty (a real TTY).
//
// omac is the single source of truth — this file parses its feeds, it never
// hard-codes the command set. `omac commands --json` drives the whole palette.

import { execFile } from "child_process";
import { existsSync, statSync } from "fs";
import { homedir } from "os";
import { promisify } from "util";
import { getPreferenceValues } from "@raycast/api";

const pExecFile = promisify(execFile);

export type Kind = "read" | "pick" | "apply" | "mutate";

/** One leaf command, exactly as `omac commands --json` emits it. */
export interface OmacCommand {
  cmd: string;
  group: string;
  title: string;
  desc: string;
  kind: Kind;
  argName: string;
  argSource: string;
  icon: string;
}

/** One selectable value for a `pick` command, parsed from its arg source. */
export interface Choice {
  value: string;
  label: string;
  badge?: string;
  current: boolean;
}

export interface RunResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

interface Preferences {
  omacPath?: string;
}

// Login shells that carry the user's PATH, mise shims, and Homebrew — the same
// environment omac expects when run from a terminal.
const LOGIN_SHELL = "/bin/zsh";

// Where omac usually installs its launcher symlink, tried in order before we fall
// back to resolving it through a login shell.
const CANDIDATE_PATHS = [
  `${homedir()}/.local/bin/omac`,
  "/opt/homebrew/bin/omac",
  "/usr/local/bin/omac",
  `${homedir()}/Code/omac/bin/omac`,
];

let cachedBin: string | undefined;

function isExecutable(path: string): boolean {
  try {
    const st = statSync(path);
    return st.isFile() && (st.mode & 0o111) !== 0;
  } catch {
    return false;
  }
}

/** Single-quote a string for safe interpolation into a shell command. */
function shq(s: string): string {
  return `'${s.replace(/'/g, `'\\''`)}'`;
}

/**
 * Locate the omac executable: an explicit preference wins, then the common
 * install locations, then `command -v omac` in a login shell. Cached for the
 * life of the command. Throws with an actionable message if nothing is found.
 */
export async function resolveOmac(): Promise<string> {
  if (cachedBin) return cachedBin;

  const { omacPath } = getPreferenceValues<Preferences>();
  if (omacPath && omacPath.trim()) {
    const p = omacPath.trim();
    if (!isExecutable(p)) {
      throw new Error(`The configured omac path is not executable: ${p}`);
    }
    cachedBin = p;
    return p;
  }

  for (const p of CANDIDATE_PATHS) {
    if (isExecutable(p)) {
      cachedBin = p;
      return p;
    }
  }

  try {
    const { stdout } = await pExecFile(LOGIN_SHELL, ["-lic", "command -v omac"]);
    const found = stdout.trim().split("\n").pop()?.trim();
    if (found && existsSync(found)) {
      cachedBin = found;
      return found;
    }
  } catch {
    // fall through to the error below
  }

  throw new Error("Could not find the omac binary. Set its path in this extension's preferences (⌘,).");
}

/**
 * Run `omac <args...>` non-interactively and capture its output. Executed
 * through a login+interactive shell so brew/mise-backed subcommands see the same
 * environment they would in a terminal. Never rejects on a non-zero exit — the
 * caller decides what a failure means.
 */
export async function runOmac(args: string[]): Promise<RunResult> {
  const bin = await resolveOmac();
  const script = `exec ${shq(bin)} ${args.map(shq).join(" ")}`;
  try {
    const { stdout, stderr } = await pExecFile(LOGIN_SHELL, ["-ilc", script], {
      maxBuffer: 8 * 1024 * 1024,
    });
    return { stdout, stderr, exitCode: 0 };
  } catch (err) {
    const e = err as { stdout?: string; stderr?: string; code?: number; message?: string };
    return {
      stdout: e.stdout ?? "",
      stderr: e.stderr ?? e.message ?? "",
      exitCode: typeof e.code === "number" ? e.code : 1,
    };
  }
}

/** Load and parse the command registry (`omac commands --json`). */
export async function loadCommands(): Promise<OmacCommand[]> {
  const { stdout, stderr, exitCode } = await runOmac(["commands", "--json"]);
  if (exitCode !== 0 && !stdout.includes("[")) {
    throw new Error(stderr || "omac commands --json failed");
  }
  // Be forgiving of any leading shell noise: slice from the first [ to the last ].
  const start = stdout.indexOf("[");
  const end = stdout.lastIndexOf("]");
  if (start === -1 || end === -1) {
    throw new Error("omac did not return a command feed");
  }
  return JSON.parse(stdout.slice(start, end + 1)) as OmacCommand[];
}

/**
 * Turn a pick command's arg source (e.g. `omac theme list`) into choices. The
 * list commands are human-formatted, so parse leniently: strip a leading status
 * glyph (● marks the current value), skip all-caps header rows, take the first
 * token as the value, and keep the remainder as a badge. Handles the three shapes
 * omac emits today — `● slug`, `slug — Label`, `slug status`, `slug ☾`.
 */
export function parseChoices(raw: string): Choice[] {
  const out: Choice[] = [];
  for (const rawLine of raw.split("\n")) {
    let line = rawLine.trim();
    if (!line) continue;

    let current = false;
    const mark = line.match(/^([●○•*])\s*/);
    if (mark) {
      if (mark[1] === "●") current = true;
      line = line.slice(mark[0].length);
    }

    const value = line.split(/\s+/)[0];
    if (!value) continue;
    if (/^[A-Z]+$/.test(value)) continue; // header row (GROUP / STATUS); slugs are lowercase

    let rest = line.slice(value.length).trim();
    rest = rest.replace(/^[—–-]\s*/, ""); // strip a separating dash
    const light = rawLine.includes("☾");
    rest = rest.replace(/☾/g, "").trim();
    const badge = light ? "light" : rest || undefined;

    out.push({ value, label: value, badge, current });
  }
  return out;
}

/** Load the choices for a pick command from its arg source command string. */
export async function loadChoices(argSource: string): Promise<Choice[]> {
  // argSource is a full command like "omac theme list"; run its tail as omac args.
  const parts = argSource.trim().split(/\s+/);
  const args = parts[0] === "omac" ? parts.slice(1) : parts;
  const { stdout } = await runOmac(args);
  return parseChoices(stdout);
}

const GHOSTTY_APP = "/Applications/Ghostty.app";

/**
 * Hand an interactive/privileged command to a real terminal. Prefers Ghostty;
 * falls back to Terminal.app. The window stays open after the command so the user
 * can read the result and answer any prompt.
 */
export async function openInTerminal(cmd: string): Promise<void> {
  const bin = await resolveOmac();
  const full = `${shq(bin)} ${cmd.trim().split(/\s+/).map(shq).join(" ")}`;
  const script = `${full}; printf '\\n[omac] done — press Return to close '; read`;

  if (existsSync(GHOSTTY_APP)) {
    await pExecFile("open", ["-na", "Ghostty", "--args", "-e", "zsh", "-ilc", script]);
    return;
  }
  // Terminal.app fallback via AppleScript.
  const osa = `tell application "Terminal"
  activate
  do script ${shq(`zsh -ilc ${shq(script)}`)}
end tell`;
  await pExecFile("osascript", ["-e", osa]);
}
