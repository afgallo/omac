# omac

**Omarchy-style, keyboard-driven, fully-themed desktop for macOS.**

One command restyles your terminal, editor, window borders, and wallpaper. Tiling and workspaces are
keyboard-native. Your whole toolchain installs from declarative manifests. omac is a *layer on
top of* macOS — not a distro — so it runs safely on your existing Mac.

![Platform: Apple Silicon](https://img.shields.io/badge/platform-Apple%20Silicon-black)
![macOS 14+](https://img.shields.io/badge/macOS-Sonoma%2014%2B-black)
![Shell: zsh](https://img.shields.io/badge/shell-zsh-black)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/afgallo/omac/main/boot.sh -o /tmp/boot.sh && zsh /tmp/boot.sh
```

Run it from a terminal — don't pipe it straight into `zsh`. Homebrew's installer needs a TTY to
prompt for your `sudo` password; a pipe has no TTY, so it fails with a misleading "needs to be an
Administrator" error.

The bootstrap is idempotent: it preflights (Apple Silicon, macOS 14+), installs Xcode Command
Line Tools and Homebrew if missing, clones the repo, and wires the `omac` CLI. Then open a new
terminal and run `omac doctor`.

## What you get

- **One-command theming** — `omac theme set <name>` propagates a palette to every app at once.
- **Modern shell** — `omac shell install` wires zsh/bash with the Starship prompt, eza/bat/fd/
  ripgrep aliases, zoxide, and fzf — all themed with the rest of the desktop.
- **Keyboard-driven desktop** — AeroSpace tiling + 6 workspaces + a JankyBorders focus border.
- **Declarative software** — curated Homebrew groups and `mise` runtimes, opt-in / opt-out.
- **Idempotent installer** — a re-entrant `git`-clone bootstrap you can re-run any time.
- **10 bundled themes** — catppuccin · catppuccin-latte · everforest · ethereal · gruvbox ·
  kanagawa · nord · ristretto · rose-pine · tokyo-night.

## Try it

```bash
omac software install       # curated Homebrew groups + mise runtimes
omac shell install          # Starship prompt + modern zsh/bash aliases and tools
omac wm install             # AeroSpace + JankyBorders + macOS tweaks (guided)
omac theme set kanagawa     # recolor the whole desktop
omac help                   # list every command
```

## Documentation

**→ Full documentation: [afgallo.github.io/omac](https://afgallo.github.io/omac)**

Getting started, the complete CLI reference, the theme and hotkey guides, and the architecture.

## Acknowledgements

omac stands on the shoulders of two projects that inspired this build:

- **[Omarchy](https://omarchy.org)** ([basecamp/omarchy](https://github.com/basecamp/omarchy)) — DHH's
  beautiful, opinionated, keyboard-driven Arch Linux. Its themes and desktop philosophy are the
  north star omac ports to macOS.
- **[Omakos](https://github.com/yatish27/omakos)** — an opinionated, idempotent macOS dev-machine
  setup that shaped how omac approaches declarative, re-runnable Homebrew provisioning.

## Development

```bash
test/run.zsh                # run the offline zsh test suite (brew/mise stubbed)
test/validate_manifests.zsh # resolve every brew/cask token against real Homebrew
mkdocs serve                # preview the docs site (see docs/contributing)
```

## Requirements

Apple Silicon (arm64) · macOS Sonoma 14, Sequoia 15, or Tahoe 26. Requires an internet connection
and admin rights.
