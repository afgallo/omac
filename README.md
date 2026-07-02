# omac

**Omarchy-style, keyboard-driven, fully-themed desktop for macOS.**

One command restyles your terminal, editor, topbar, and wallpaper. Tiling and workspaces are
keyboard-native. Your whole toolchain installs from declarative manifests. omac is a *layer on
top of* macOS — not a distro — so it runs safely on your existing Mac.

![Platform: Apple Silicon](https://img.shields.io/badge/platform-Apple%20Silicon-black)
![macOS 14+](https://img.shields.io/badge/macOS-Sonoma%2014%2B-black)
![Shell: zsh](https://img.shields.io/badge/shell-zsh-black)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/afgallo/omac/main/boot.sh | zsh
```

The bootstrap is idempotent: it preflights (Apple Silicon, macOS 14+), installs Xcode Command
Line Tools and Homebrew if missing, clones the repo, and wires the `omac` CLI. Then open a new
terminal and run `omac doctor`.

## What you get

- **One-command theming** — `omac theme set <name>` propagates a palette to every app at once.
- **Keyboard-driven desktop** — AeroSpace tiling + 6 workspaces + a SketchyBar topbar.
- **Declarative software** — curated Homebrew groups and `mise` runtimes, opt-in / opt-out.
- **Idempotent installer** — a re-entrant `git`-clone bootstrap you can re-run any time.
- **10 bundled themes** — catppuccin · catppuccin-latte · everforest · ethereal · gruvbox ·
  kanagawa · nord · ristretto · rose-pine · tokyo-night.

## Try it

```bash
omac software install       # curated Homebrew groups + mise runtimes
omac wm install             # AeroSpace + SketchyBar + macOS tweaks (guided)
omac theme set kanagawa     # recolor the whole desktop
omac help                   # list every command
```

## Documentation

**→ Full documentation: [afgallo.github.io/omac](https://afgallo.github.io/omac)**

Getting started, the complete CLI reference, the theme and hotkey guides, and the architecture.

## Development

```bash
test/run.zsh                # run the zsh test suite
mkdocs serve                # preview the docs site (see docs/contributing)
```

## Requirements

Apple Silicon (arm64) · macOS Sonoma 14, Sequoia 15, or Tahoe 26. Requires an internet connection
and admin rights.
