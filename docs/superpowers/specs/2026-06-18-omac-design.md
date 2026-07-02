# omac — Master Design

**Status:** Approved design · **Date:** 2026-06-18 · **Audience:** personal, cleanly shareable later

## What this is

`omac` is an Omarchy-style, keyboard-driven, fully-themed desktop environment for macOS. It
reproduces the parts of Omarchy that the user values most — keyboard-only navigation, automatic
tiling, workspaces, and one-command theme switching that propagates to *everything* (terminal,
editor, topbar, wallpaper, and more) — by assembling mature macOS tools and building the one
piece that doesn't exist on Mac: a theme-orchestration layer.

It is **not** a Linux distro clone. Anything macOS already does natively (disk encryption,
snapshots, firewall, biometric auth, OS install) is deliberately out of scope.

## Goals

- One command (`omac theme set <name>`) restyles terminal, Neovim, editors, topbar, wallpaper,
  macOS light/dark appearance, and the CLI ecosystem — instantly, everywhere.
- Keyboard-driven tiling + workspaces with an Omarchy-familiar hotkey philosophy.
- Idempotent, re-runnable installer that provisions dev tools, AI tools, IDEs, fonts, and apps.
- Day one looks familiar: the user's existing 19 Omarchy themes are ported over.
- Personal-first, but written clean enough (no hardcoded usernames/paths, idempotent, documented)
  to share later.

## Non-goals (deliberately dropped — macOS native)

ISO/BIOS/disk-encryption install, system snapshots (Time Machine/APFS), LUKS/firewall security,
hardware auth (Touch ID), boot/branding logo, system sleep/hibernation tuning, manual install,
Windows VM, gaming. *(Windows VM and gaming may become optional add-on modules later; they are
not part of the core.)*

## Supported platform & prerequisites

- **macOS:** **Sonoma 14, Sequoia 15, and Tahoe 26** (Apple's year-based numbering jumped 15→26,
  so there is no 16–25). Preflight enforces a major-version floor of 14 and refuses anything older.
- **Architecture:** **Apple Silicon (arm64) only.** Homebrew prefix is therefore always
  `/opt/homebrew`. Preflight refuses Intel.
- **A clean macOS install is recommended, not required.** omac is a *layer on top of* macOS, not a
  distro that wipes the disk. It must be idempotent and non-destructive (managed config blocks,
  confirm-before-overwrite) so it runs safely on an existing Mac. A clean install is documented as
  the way to get the full pristine "rice" on first run.
- **Auto-provisioned by the installer:** Xcode Command Line Tools, Homebrew. **Required of the
  user:** an internet connection and admin rights.

## Canonical paths (reserved by `bootstrap`, used by later modules)

| Path | Side | Role |
|---|---|---|
| `~/.local/share/omac` | repo (read-only) | cloned omac: scripts, defaults, themes, templates, migrations. |
| `~/.local/share/omac/themes/<name>/` | repo | ported per-app theme files + `colors.toml`. |
| `~/.local/share/omac/templates/` | repo | palette-rendered templates for Mac-only targets. |
| `~/.config/omac` | user state | `config.zsh`, local overrides, selected theme. |
| `~/.config/omac/current` | user state | symlink → active theme dir (lives on the *user-state* side). |
| `~/.local/state/omac/migrations` | user state | applied-migration ledger. |

macOS does not set `$XDG_*` by default; omac derives these via explicit fallbacks
(`${XDG_CONFIG_HOME:-$HOME/.config}`). This XDG-on-macOS layout is a deliberate choice that mirrors
Omarchy to lower porting friction — not an oversight; do not "fix" it by moving to `~/Library`.

## Tool decisions

| Concern | Choice | Notes |
|---|---|---|
| Tiling + workspaces | **AeroSpace** | Pure userspace, no SIP changes, TOML config. Trade-off: minimal animations. |
| Launcher / kbd command surface | **Raycast** | App launch, clipboard history, snippets, extensions calling into `omac` CLI. |
| Topbar | **SketchyBar** | Waybar equivalent; theme-driven. |
| Terminal | **Ghostty** | Canonical themed terminal. |
| Package manager | **Homebrew** | Brewfile-driven, idempotent installs. |
| Runtime manager | **mise** | Already in use; Ruby/Node/bun/Deno/Python/Go. |

## Theme-orchestration architecture (the heart)

**Hybrid: file-per-app (ported) + palette-derived (Mac-only targets).**

- Each `themes/<name>/` directory holds ready-made per-app files ported straight from the user's
  existing Omarchy themes (`ghostty.conf`, `neovim.lua`, `btop.theme`, `vscode.json`, backgrounds,
  starship, tmux, bat, lazygit, delta, etc.). These drop in almost unchanged.
- Each theme dir also carries a small `colors.toml` palette. For the targets Omarchy never had —
  **macOS light/dark appearance, SketchyBar, Raycast, AeroSpace accent/border colors** — `omac`
  *derives* the config from that palette via a templating seam (no hand-porting, since there's
  nothing to port).
- `omac theme set <name>` repoints the `~/.config/omac/current` symlink (see Canonical paths),
  renders the palette-derived targets from `templates/`, and reloads each app. Mirrors Omarchy's
  `theme-set` model. The `themes/`, `templates/`, and `current` paths are *reserved by `bootstrap`*
  so this module doesn't have to retrofit the layout later.

This minimizes porting friction now while keeping a clean path to palette-only new themes later.

## Module decomposition

Independent sub-projects, each with its own spec → plan → build cycle. Build order top to bottom.

1. **`bootstrap`** — installer + `omac` CLI command center; updates (`brew upgrade` + migrations).
   *(Omarchy: CLI, Updates, Other Packages.)*
2. **`software`** — declarative Brewfile-style manifests, opt-in/out groups: languages/runtimes
   (mise), IDEs (VS Code, Cursor, Zed, Kiro, Sublime, Helix), AI tools (Claude Code, OpenCode,
   agent CLIs, LM Studio), shell tools (fzf, zoxide, ripgrep, bat, eza, fd), TUIs (lazygit,
   lazydocker, btop), GUI apps (Obsidian, 1Password, Typora, LocalSend, mpv, image editor),
   fonts (JetBrainsMono Nerd Font + programming-font set).
   *(Omarchy: Development Tools, AI Tools, Shell Tools, TUIs, GUIs, Commercial Apps, Fonts.)*
3. **`wm`** — AeroSpace + SketchyBar + global hotkey map; universal-clipboard behavior; tweaks.
   *(Omarchy: Navigation, Hotkeys, Universal Clipboard, Common Tweaks, Monitors, Input.)*
4. **`launcher`** — Raycast config: app launch, "Omarchy Menu" command surface, clipboard history,
   snippets, custom commands calling the `omac` CLI.
   *(Omarchy: Navigation, Web Apps, Reminders/Notices/OCR/Dictation as extensions.)*
5. **`theme`** — the orchestration layer above; ports the 19 themes + palette-derived Mac targets.
   *(Omarchy: Themes, Extra Themes, Making Your Own Theme, Backgrounds, Fonts.)*
6. **`dotfiles`** — config storage/deploy substrate all modules write through. Mechanism chosen in
   that sub-project's spec. *(Omarchy: Dotfiles.)*

## Reference implementations (to mine, not to follow)

[yatish27/omakos](https://github.com/yatish27/omakos) is a static, single-run macOS dev-machine
setup (Bash + a Homebrew Brewfile + per-tool scripts). It has no theme orchestration, no CLI, and no
update engine, so it is a *parts bin*, not a blueprint. Concretely reusable when those module specs
are written:

- **`software`:** its `configs/Brewfile` is a curated brew/cask/font list that overlaps omac heavily
  (Ghostty, Raycast, mise, 1Password, Obsidian, LocalSend, Zed, Cursor, Claude, fonts) — a ready
  seed once the opt-in/out group layer is designed. Swap Rectangle → AeroSpace; add SketchyBar.
- **`wm`:** its `scripts/mac.sh` is a curated `defaults write` catalog (key-repeat, Finder,
  three-finger-drag, Dock animation removal, screenshots→folder, disable press-and-hold) — mine the
  individual settings for the "Common Tweaks / Input" surface; drop its unconditional `killall`.
- **`theme` / `dotfiles`:** deploy configs through the `omac::install_file` diff-and-backup helper
  that `bootstrap` provides, not a blind `cp`.

Deliberately *not* copied: its zip-download + `rm -rf` installer (omac uses a re-entrant git clone),
its inverted/Linux-only `check_internet_connection`, and its committed 1120-line iTerm2 plist (omac
derives Mac targets from a palette instead).

[basecamp/omarchy](https://github.com/basecamp/omarchy) is the Linux project omac emulates — mature
(300+ migrations, a full update/state subsystem), so it is worth mining for mechanisms, not layout
(its `bin/` is ~250 flat `omarchy-<area>-<verb>` scripts; omac keeps its dispatcher + `cmd/`). Already
folded into `bootstrap`:

- **Fresh-install migration baselining** — stamp existing migrations as applied on first install so a
  new machine never replays history. A real correctness gap omac's first draft had.
- **Skip-tracking for failed migrations** — a broken migration can be skipped into a separate ledger
  instead of blocking every later migration.

Reserved for later modules:

- **First-run marker** (`wm`/`software`) — a one-shot post-install hook for GUI-session steps a piped
  installer can't do: Accessibility/Screen-Recording grants, launching AeroSpace/SketchyBar.

Deliberately *not* adopted: its release-channel/mirror system (omac is single-channel, personal) and
its hardware-detection matrix (`omarchy-hw-*`) — Apple Silicon is a single, known platform.

## Optional polish (deferred to v1.1)

Reminders, Notices (weather/battery/time), OCR text-extraction, AI dictation (Voxtype → macOS
dictation or a Whisper tool). All small and Raycast-extension-shaped.

## Build order rationale

`bootstrap` first (everything installs through it). `software` next (the rest needs the tools
present). `wm` + `launcher` give a usable keyboard-driven desktop. `theme` is the payoff and
depends on the apps from earlier modules existing. `dotfiles` is the substrate — its mechanism is
decided early but it stabilizes as modules land. First sub-project to spec in detail: **`bootstrap`**.

> **Build-order note (2026-07-02):** after completing `wm`, we chose to build **`theme` (module 5)
> before `launcher` (module 4)**. `theme` has no dependency on `launcher` — their Raycast surfaces are
> orthogonal (`theme` owns Raycast's *colors*; `launcher` owns its *Script Commands*) — it is the
> headline payoff, and building it now validates the `wm` color-seam architecture while it is fresh.
> `launcher` stays fully unblocked (its only outstanding build dep, `wm`, is done) and follows `theme`.
> Module numbers are stable identities, not the build sequence. Launcher decisions captured so far
> live in `2026-07-02-omac-launcher-decisions.md`.

## Open questions for sub-project specs

- `dotfiles` mechanism: GNU Stow vs bare git repo vs custom symlink script (decided in `dotfiles` spec).
- Exact `omac` CLI surface and subcommand grammar (decided in `bootstrap` spec).
- Per-app reload mechanics on macOS (decided in `theme` spec).
