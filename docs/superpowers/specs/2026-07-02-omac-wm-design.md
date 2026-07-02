# omac `wm` module — design

**Status:** Approved design · **Date:** 2026-07-02 · **Parent:** `2026-06-18-omac-design.md` (module 3 of 5)

## What this is

The `wm` module is the **window-manager configuration layer** for omac. It turns a freshly
installed AeroSpace + SketchyBar into a working, keyboard-driven, Omarchy-familiar desktop by
deploying config, wiring the global hotkey map, applying a curated set of macOS "common tweaks",
and running a guided first-run activation.

Its single responsibility is **configuring the desktop's structure and behavior** — not installing
it (that is `software`, which already ships aerospace, sketchybar, ghostty, and raycast in
`guis.Brewfile`) and not styling it (that is `theme`, module 5, which owns all colors). `wm` is a
pure configuration layer that sits between the two.

## Goals

- `omac wm install` takes installed-but-unconfigured AeroSpace + SketchyBar to a usable,
  keyboard-driven desktop in one command, including the manual-grant handholding macOS forces.
- The AeroSpace hotkey map reproduces the user's existing Omarchy bindings
  (<https://github.com/afgallo/omarchy-dotfiles>) so day-one muscle memory survives the OS switch.
- macOS "common tweaks" (key-repeat, caps→escape, trackpad, Finder, Dock) are applied declaratively
  and idempotently from a single manifest.
- Idempotent and re-runnable — configs deploy via the existing diff/backup `omac::install_file`;
  tweaks lean on `defaults write` being idempotent.
- One engine (`lib/wm.zsh`) is the single source of truth; the `cmd/wm/*` scripts are thin.
- Colors are deliberately absent so the `theme` module can own them without fighting `wm`.

## Non-goals (v1)

- **No colors / theming.** AeroSpace ships structural-only (no borders); SketchyBar ships neutral
  default colors in a `colors.sh` seam that the `theme` module will later own. Window borders
  (JankyBorders) are deferred to `theme`/v1.1.
- **No monitor-specific config.** Omarchy's `monitors-*.conf` per-host layout is deferred to v1.1.
- **No universal-clipboard polish.** macOS handles clipboard natively; Raycast clipboard history is
  the `launcher` module's concern.
- **No package installation.** All casks/formulae come from `software`.
- **No skhd or second hotkey daemon.** All bindings live in AeroSpace's own always-on binding
  system; Raycast (the `launcher` module) owns the command-palette / app-launcher surface.

## Layout

```
wm/
  aerospace/
    aerospace.toml            # structural: workspaces, layouts, gaps, bindings, sketchybar hook
  sketchybar/
    sketchybarrc              # executable entry point; sources colors.sh
    colors.sh                 # NEUTRAL default palette — the seam the theme module will own
    plugins/                  # item plugins (workspaces, clock, battery, …), each +x
  tweaks.conf                 # declarative `domain key type value` list for defaults write
lib/wm.zsh                    # the engine — all aerospace/sketchybar/tweaks logic lives here
cmd/wm.zsh                    # bare `omac wm` → usage + brief status
cmd/wm/install.zsh            # omac wm install  → deploy + tweaks + guided activation
cmd/wm/reload.zsh             # omac wm reload   → reload aerospace + sketchybar
cmd/wm/status.zsh             # omac wm status   → deployed / running / granted per component
```

This mirrors the `software` module's shape exactly: thin command scripts over one namespaced engine.

### Dispatcher fit (no changes to `bin/omac`)

The existing resolver already supports this shape:

- `omac wm install` → `omac::resolve wm install` matches `cmd/wm/install.zsh` (depth 2); the
  dispatcher consumes the `install` token.
- `omac wm reload` / `omac wm status` → `cmd/wm/reload.zsh` / `cmd/wm/status.zsh`.
- `omac wm` (bare) → depth-2 branch skipped (no sub-token), falls to `cmd/wm.zsh` (depth 1) → usage.
- `omac wm bogus` → no `cmd/wm/bogus.zsh`, falls to `cmd/wm.zsh` with `$1=bogus`; usage notes the
  unknown subcommand and returns non-zero (same convention as `cmd/software.zsh`).

## The engine — `lib/wm.zsh`

All logic lives here so `cmd/wm/*` stay thin. Functions are namespaced `omac::wm::<verb>`.

| Function | Behavior |
|---|---|
| `omac::wm::config_dir` | Print `${XDG_CONFIG_HOME:-$HOME/.config}` (the deploy root). One place so tests can redirect via `XDG_CONFIG_HOME`. |
| `omac::wm::deploy_aerospace` | `omac::install_file "$OMAC_WM/aerospace/aerospace.toml"` → `<config_dir>/aerospace/aerospace.toml`. If a conflicting `~/.aerospace.toml` exists, `omac::backup_path` it and warn (AeroSpace errors when both locations exist). |
| `omac::wm::deploy_sketchybar` | `omac::install_file` each file under `$OMAC_WM/sketchybar/` into `<config_dir>/sketchybar/`, preserving the tree; `chmod +x` the `sketchybarrc` entry and every `plugins/*`. |
| `omac::wm::apply_tweaks` | Read `$OMAC_WM/tweaks.conf`; for each non-blank/non-`#` line `domain key type value`, run `defaults write <domain> <key> -<type> <value>`. Idempotent; a bad line warns and continues. |
| `omac::wm::activate` | Enable start-at-login (AeroSpace `start-at-login` is in its TOML; ensure it is running), `brew services start sketchybar`, start/reload both, then `open` the Accessibility System-Settings pane and print the single manual grant step. |
| `omac::wm::reload` | `aerospace reload-config` and `sketchybar --reload`. |
| `omac::wm::status` | Non-mutating: for aerospace + sketchybar print deployed? (config present) / running? (process/`brew services`) and, for AeroSpace, whether it appears to have Accessibility (best-effort). |
| `omac::wm::install` | Orchestrates `deploy_aerospace` → `deploy_sketchybar` → `apply_tweaks` → `activate`. This is the "guided auto-start" flow. |

Guards: a missing `aerospace`, `sketchybar`, or `brew` is a hard error that points the user at
`omac software install` (which owns those installs); non-zero return.

## AeroSpace config (`wm/aerospace/aerospace.toml`)

Structural only — TOML 1.1.0, deployed to `${XDG_CONFIG_HOME:-$HOME/.config}/aerospace/aerospace.toml`
(omac's XDG-on-macOS convention; AeroSpace supports this path and errors only if `~/.aerospace.toml`
*also* exists, which the deploy step guards against).

- **Modifier = Cmd** (`cmd-…`). Chosen for literal muscle-memory parity with the user's Omarchy
  `SUPER` map. AeroSpace registers bindings as global hotkeys, so only the specific Cmd combos the
  map binds are intercepted; every unbound Cmd combo (Cmd+C/V/T/W/Z/S…) stays native to the focused
  app. One deliberate consequence: **Cmd+Q becomes "close window"** (Omarchy `killactive`), not
  macOS "quit application".
- **Workspaces 1–9**, `default-root-container-layout = 'tiles'`, sane `gaps` (inner/outer).
- **`exec-on-workspace-change`** wired to `sketchybar --trigger aerospace_workspace_change …` so the
  topbar reflects the focused workspace (AeroSpace's native SketchyBar integration).
- **`start-at-login = true`**.
- No colors, no borders (owned by `theme` / deferred to v1.1).

### Binding map (Omarchy → AeroSpace, `SUPER` → `Cmd`)

**Window management / tiling — AeroSpace-native commands:**

| Omarchy binding | AeroSpace binding |
|---|---|
| `SUPER+SHIFT+H/J/K/L` — move focus (vim keys) | `cmd-shift-h/j/k/l = focus left/down/up/right` |
| `SUPER+1..9` — switch workspace (Omarchy default) | `cmd-1..9 = workspace 1..9` |
| `SUPER+SHIFT+1..9` — move window to workspace (default) | `cmd-shift-1..9 = move-node-to-workspace N` |
| `SUPER+Q` — close window (`killactive`) | `cmd-q = close` *(overrides macOS quit — intentional)* |
| fullscreen | `macos-native-fullscreen` (toggle) |
| toggle float | `layout floating tiling` |
| toggle split layout | `layout tiles accordion` |
| resize | a `resize` sub-mode: `cmd-r` enters, `h/j/k/l` resize, `enter/esc` exits |

**Application launches — `exec-and-forget open …`, mirroring the user's `bindings.conf`:**

| Omarchy binding | AeroSpace binding |
|---|---|
| `SUPER+RETURN` — Terminal | `open -na Ghostty` |
| `SUPER+ALT+RETURN` — Tmux | `open -na Ghostty` then `tmux attach ‖ tmux new -s Work` |
| `SUPER+SHIFT+B` / `SUPER+SHIFT+RETURN` — Browser | `open -a <browser>` *(browser configurable; default the system default)* |
| `SUPER+SHIFT+N` — Editor | `open -a <editor>` |
| `SUPER+SHIFT+O/S/M/G` — Obsidian / Slack / Spotify / Signal | `open -a <App>` (`open -a` focuses-if-running = Omarchy `launch-or-focus`) |
| `SUPER+SHIFT+A/C/E/Y/X` — webapps (ChatGPT/Claude/Email/YouTube/X) | `open <url>` |
| `SUPER+SHIFT+P` — Screenshot | `screencapture -i` (interactive region) |

**Dropped (macOS-native or another module's concern):**

- Brightness (`bindings-macarch.conf`) and `media.conf` — macOS handles these on the native F-keys.
- `clipboard.conf` — native Cmd+C/V plus Raycast clipboard history in the `launcher` module.
- Linux launch helpers (`uwsm-app`, `omarchy-launch-*`, `nautilus`, `brightnessctl`) — replaced by
  `open`/`open -a`/`screencapture`.

**Deliberate scope note:** the webapp launches (`open <url>`) are arguably `launcher` (Raycast)
territory. They stay in `wm` for v1 so muscle memory survives day one; the `launcher` module is
expected to grow into the primary command surface over time and may relocate them later. Moving them
is a config edit, not a mechanism change.

## SketchyBar config (`wm/sketchybar/`)

A structural topbar only:

- `sketchybarrc` — the executable entry point. It **sources a sibling `colors.sh`** for every color
  value it uses.
- `colors.sh` — neutral default palette shipped by `wm`. **This file is the seam:** the `theme`
  module (module 5) will later overwrite it (rendered from the theme's `colors.toml` palette), so
  `wm` never hardcodes theme colors inline and the two modules never fight.
- `plugins/` — item scripts, each `chmod +x`: workspace indicators (driven by AeroSpace's
  `aerospace_workspace_change` trigger), a clock, and a battery indicator (percentage + charging
  state, refreshed on a timer). Colors come from the `colors.sh` seam, never hardcoded.

`wm` performs **no palette rendering** — it ships working neutral defaults and leaves palette
derivation to `theme`.

## Common tweaks (`wm/tweaks.conf`)

A declarative manifest, one `domain key type value` per line (blank/`#` lines ignored), applied
idempotently via `defaults write <domain> <key> -<type> <value>`. Mined from omakos' `scripts/mac.sh`
catalog and the user's Omarchy `input.conf`; omakos' unconditional `killall` is **not** adopted
(reload is explicit via `omac wm reload` / re-login where required).

Seed set:

- **Keyboard:** fast key repeat (`KeyRepeat`, `InitialKeyRepeat` — the user's `repeat_rate=50` /
  `repeat_delay=300`); disable press-and-hold so key repeat works in apps
  (`ApplePressAndHoldEnabled=false`).
- **Caps Lock → Escape** (the user's `caps:escape`).
- **Trackpad:** three-finger drag; two-finger/clickfinger right-click (the user's
  `clickfinger_behavior`).
- **Finder:** show all file extensions; show path bar; screenshots saved to a dedicated folder.
- **Dock:** autohide; remove launch/animation delay.

**Reversibility (deferred to v2.0):** the `defaults`-based tweaks are applied one-way in v1; a `wm`
reversal path that restores prior values on `omac uninstall` is **deferred to v2.0**. Caps→Escape is a
session-scoped `hidutil` remap (no LaunchAgent persistence in v1), so it self-reverts on the next
reboot and needs no explicit uninstall step. `omac uninstall` therefore reverses only the `bootstrap`
(CLI symlink, `~/.zprofile` block) and `launcher` (Spotlight ⌘Space) changes in v1.

## First-run activation (guided auto-start)

`omac wm install` runs the full guided flow, all steps idempotent/re-runnable:

1. `deploy_aerospace` + `deploy_sketchybar` (diff/backup via `omac::install_file`).
2. `apply_tweaks`.
3. `activate`: ensure `start-at-login`, `brew services start sketchybar`, start/reload AeroSpace and
   SketchyBar, then `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`
   and print the one manual step (grant AeroSpace Accessibility) that macOS forbids scripting.

## CLI surface

- `omac wm` → usage + brief status; unknown subcommand token → warn + return 1.
- `omac wm install` → the guided flow above.
- `omac wm reload` → `aerospace reload-config` + `sketchybar --reload`.
- `omac wm status` → deployed / running / accessibility-granted per component.

## Error handling

| Situation | Behavior |
|---|---|
| `aerospace` / `sketchybar` / `brew` missing | Hard error pointing at `omac software install`; non-zero. |
| Conflicting `~/.aerospace.toml` present | Back it up (`omac::backup_path`), warn, deploy to the XDG path. |
| A `tweaks.conf` line fails | Warn and continue the remaining tweaks; summarize. |
| Accessibility not granted | Cannot be scripted — `activate` opens the pane and prints the step; `status` reports best-effort. |
| Unknown subcommand | Usage notes it; non-zero. |

## Testing

Follows the existing `test_*.zsh` pattern (`check`/`contains`/`finish`, fake `OMAC_HOME` from
symlinked `lib`/`bin`/`cmd` + `mktemp` dirs). Real system state must never be touched:

- **Stub `aerospace`, `sketchybar`, `brew`, `defaults`, and `open`** as scripts on a temp dir
  prepended to `PATH` that log their arguments and exit 0 (the `software_stubs.zsh` approach; a
  `wm_stubs.zsh` helper adds the new binaries).
- Point **`OMAC_WM`** at a temp source tree and **`XDG_CONFIG_HOME`** at a temp deploy dir.

Assertions:

- `omac wm install` deploys `aerospace.toml` to `<XDG_CONFIG_HOME>/aerospace/` and the sketchybar
  tree to `<XDG_CONFIG_HOME>/sketchybar/` (files present, entry + plugins executable).
- `apply_tweaks` turns each `tweaks.conf` line into a `defaults write …` call (assert on the stub log).
- `omac wm install` invokes activation (`brew services start sketchybar`, `open …Accessibility`,
  aerospace/sketchybar start-or-reload) — assert on stub logs.
- `omac wm reload` calls `aerospace reload-config` and `sketchybar --reload`.
- Missing-binary path errors and points at `omac software install`.
- `omac wm` (bare) prints usage, exit 0; `omac wm bogus` → non-zero.

## New env override

`OMAC_WM` — root of the `wm` config sources, default `$OMAC_HOME/wm`. Added to `lib/paths.zsh`
alongside the existing overrides so tests can point at a fixture dir. Deploy targets are derived from
`${XDG_CONFIG_HOME:-$HOME/.config}` so tests redirect them via `XDG_CONFIG_HOME`. No user-facing
config change.

## Open questions

None. The AeroSpace↔SketchyBar color seam (`colors.sh`) is defined for the `theme` module to own;
the webapp-binding ownership (wm vs. launcher) is a future config move, not a mechanism change.
