// The omac command palette. One Raycast view lists every omac command, grouped
// exactly as the CLI groups them, and honors each command's `kind`:
//
//   read   → run inline, show the output in a Detail pane
//   apply  → run inline (a non-interactive mutation), show output + a toast
//   pick   → choose a value from the command's arg source, then run it
//   mutate → hand off to Ghostty, a real TTY, for interactive/privileged work
//
// The command set is never hard-coded here; it comes from `omac commands --json`.

import {
  Action,
  ActionPanel,
  Alert,
  Color,
  Detail,
  Icon,
  Image,
  List,
  Toast,
  closeMainWindow,
  confirmAlert,
  showHUD,
  showToast,
} from "@raycast/api";
import { showFailureToast, usePromise } from "@raycast/utils";
import { Choice, Kind, OmacCommand, loadChoices, loadCommands, openInTerminal, runOmac } from "./lib/omac";

// ── presentation helpers ────────────────────────────────────────────────────

const ICON_HINTS: Record<string, Icon> = {
  paintbrush: Icon.Brush,
  text: Icon.Text,
  download: Icon.Download,
  image: Icon.Image,
};

const KIND_ICON: Record<Kind, Icon> = {
  read: Icon.Eye,
  pick: Icon.List,
  apply: Icon.Bolt,
  mutate: Icon.Terminal,
};

const KIND_COLOR: Record<Kind, Color> = {
  read: Color.Blue,
  pick: Color.Purple,
  apply: Color.Green,
  mutate: Color.Orange,
};

function iconFor(c: OmacCommand): Image.ImageLike {
  if (c.icon && ICON_HINTS[c.icon]) return ICON_HINTS[c.icon];
  return KIND_ICON[c.kind];
}

function argsOf(cmd: string): string[] {
  return cmd.trim().split(/\s+/);
}

// Strip ANSI color escapes so command output reads cleanly in a Detail pane.
function stripAnsi(s: string): string {
  // eslint-disable-next-line no-control-regex
  return s.replace(/\[[0-9;]*m/g, "");
}

function outputMarkdown(title: string, body: string): string {
  const clean = stripAnsi(body).trimEnd();
  return `### ${title}\n\n\`\`\`\n${clean || "(no output)"}\n\`\`\``;
}

// ── output pane (read + apply) ───────────────────────────────────────────────

function OutputView({ command }: { command: OmacCommand }) {
  const { data, isLoading, revalidate } = usePromise(
    async (cmd: string, kind: Kind) => {
      const res = await runOmac(argsOf(cmd));
      const ok = res.exitCode === 0;
      if (kind === "apply") {
        await showToast({
          style: ok ? Toast.Style.Success : Toast.Style.Failure,
          title: ok ? "Applied" : "Failed",
          message: `omac ${cmd}`,
        });
      } else if (!ok) {
        await showToast({ style: Toast.Style.Failure, title: "Failed", message: `omac ${cmd}` });
      }
      return res;
    },
    [command.cmd, command.kind],
  );

  const body = data ? [data.stdout, data.stderr].filter(Boolean).join("\n") : "";
  const markdown = isLoading
    ? `### omac ${command.cmd}\n\nRunning…`
    : outputMarkdown(`omac ${command.cmd}`, body);

  return (
    <Detail
      isLoading={isLoading}
      navigationTitle={`omac ${command.cmd}`}
      markdown={markdown}
      actions={
        <ActionPanel>
          <Action title="Run Again" icon={Icon.ArrowClockwise} onAction={() => revalidate()} />
          {data ? <Action.CopyToClipboard title="Copy Output" content={stripAnsi(body)} /> : null}
          <Action.CopyToClipboard
            title="Copy Command"
            content={`omac ${command.cmd}`}
            shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
          />
        </ActionPanel>
      }
    />
  );
}

// ── pick pane ────────────────────────────────────────────────────────────────

function PickView({ command }: { command: OmacCommand }) {
  const { data, isLoading } = usePromise(async (source: string) => loadChoices(source), [command.argSource]);

  async function run(choice: Choice) {
    await closeMainWindow();
    await showHUD(`Running omac ${command.cmd} ${choice.value}`);
    try {
      await openInTerminal(`${command.cmd} ${choice.value}`);
    } catch (err) {
      await showFailureToast(err, { title: "Could not open a terminal" });
    }
  }

  return (
    <List
      isLoading={isLoading}
      navigationTitle={`omac ${command.cmd}`}
      searchBarPlaceholder={`Choose a ${command.argName || "value"}…`}
    >
      {(data ?? []).map((choice) => (
        <List.Item
          key={choice.value}
          title={choice.label}
          icon={choice.current ? Icon.CheckCircle : Icon.Circle}
          accessories={[
            choice.current ? { tag: { value: "current", color: Color.Green } } : {},
            choice.badge ? { text: choice.badge } : {},
          ]}
          actions={
            <ActionPanel>
              <Action title="Run in Ghostty" icon={Icon.Terminal} onAction={() => run(choice)} />
              <Action.CopyToClipboard title="Copy Command" content={`omac ${command.cmd} ${choice.value}`} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

// ── mutate (Ghostty hand-off) ────────────────────────────────────────────────

async function runMutate(command: OmacCommand) {
  const destructive = /\b(uninstall|remove|reset)\b/.test(command.cmd);
  if (destructive) {
    const ok = await confirmAlert({
      title: `Run omac ${command.cmd}?`,
      message: "This changes your system. It will open in Ghostty where you can confirm or cancel.",
      primaryAction: { title: "Open in Ghostty", style: Alert.ActionStyle.Destructive },
    });
    if (!ok) return;
  }
  await closeMainWindow();
  await showHUD(`Opening omac ${command.cmd} in Ghostty`);
  try {
    await openInTerminal(command.cmd);
  } catch (err) {
    await showFailureToast(err, { title: "Could not open a terminal" });
  }
}

// ── the palette ──────────────────────────────────────────────────────────────

function primaryAction(command: OmacCommand) {
  switch (command.kind) {
    case "read":
      return <Action.Push title="Show Output" icon={Icon.Eye} target={<OutputView command={command} />} />;
    case "apply":
      return <Action.Push title="Run" icon={Icon.Bolt} target={<OutputView command={command} />} />;
    case "pick":
      return <Action.Push title="Choose…" icon={Icon.List} target={<PickView command={command} />} />;
    case "mutate":
      return <Action title="Open in Ghostty" icon={Icon.Terminal} onAction={() => runMutate(command)} />;
  }
}

export default function Command() {
  const { data, isLoading, error } = usePromise(loadCommands);

  if (error) {
    return (
      <Detail
        markdown={`## omac not found\n\n${error.message}\n\nSet the omac binary path in this extension's preferences (⌘,).`}
      />
    );
  }

  // Preserve the registry's group order (General first, then modules as scanned).
  const groups: string[] = [];
  for (const c of data ?? []) if (!groups.includes(c.group)) groups.push(c.group);

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search omac commands…">
      {groups.map((group) => (
        <List.Section key={group} title={group}>
          {(data ?? [])
            .filter((c) => c.group === group)
            .map((c) => (
              <List.Item
                key={c.cmd}
                title={c.title}
                subtitle={c.cmd}
                icon={iconFor(c)}
                keywords={c.cmd.split(/\s+/)}
                accessories={[{ text: c.desc }, { tag: { value: c.kind, color: KIND_COLOR[c.kind] } }]}
                actions={
                  <ActionPanel>
                    {primaryAction(c)}
                    <Action.CopyToClipboard
                      title="Copy Command"
                      content={`omac ${c.cmd}`}
                      shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                    />
                  </ActionPanel>
                }
              />
            ))}
        </List.Section>
      ))}
    </List>
  );
}
