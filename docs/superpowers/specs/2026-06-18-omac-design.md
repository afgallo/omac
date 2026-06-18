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
- `omac theme set <name>` repoints a `current/` symlink, renders the palette-derived targets, and
  reloads each app. Mirrors Omarchy's `theme-set` model.

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

## Optional polish (deferred to v1.1)

Reminders, Notices (weather/battery/time), OCR text-extraction, AI dictation (Voxtype → macOS
dictation or a Whisper tool). All small and Raycast-extension-shaped.

## Build order rationale

`bootstrap` first (everything installs through it). `software` next (the rest needs the tools
present). `wm` + `launcher` give a usable keyboard-driven desktop. `theme` is the payoff and
depends on the apps from earlier modules existing. `dotfiles` is the substrate — its mechanism is
decided early but it stabilizes as modules land. First sub-project to spec in detail: **`bootstrap`**.

## Open questions for sub-project specs

- `dotfiles` mechanism: GNU Stow vs bare git repo vs custom symlink script (decided in `dotfiles` spec).
- Exact `omac` CLI surface and subcommand grammar (decided in `bootstrap` spec).
- Per-app reload mechanics on macOS (decided in `theme` spec).
