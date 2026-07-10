# omac

**Omarchy-style, keyboard-driven, fully-themed desktop for macOS.**

One command restyles your terminal, editor, window borders, and wallpaper. Tiling and workspaces are
keyboard-native. Your whole toolchain installs from declarative manifests. omac is a *layer on
top of* macOS — not a distro — so it runs safely on your existing Mac.

<div data-cast="assets/omac-theme.cast" style="max-width:760px;margin:1.5rem 0;"></div>

```bash
curl -fsSL https://raw.githubusercontent.com/afgallo/omac/main/boot.sh | zsh
```

## What you get

- **One-command theming** — `omac theme set <name>` propagates a palette to every app at once.
- **Keyboard-driven desktop** — AeroSpace tiling + 6 workspaces + a JankyBorders focus border.
- **Declarative software** — curated Homebrew groups and `mise` runtimes, opt-in / opt-out.
- **Idempotent installer** — a re-entrant `git`-clone bootstrap you can re-run any time.
- **10 bundled themes** — ported from Omarchy, plus palette-derived macOS targets.

## Requirements

Apple Silicon (arm64) · macOS Sonoma 14, Sequoia 15, or Tahoe 26.

[Get started →](getting-started/requirements.md){ .md-button .md-button--primary }
[Browse the commands →](commands/index.md){ .md-button }

!!! note "The demo above is a placeholder"
    The real `omac theme set` cast is recorded on an installed machine — see
    [Contributing](contributing/index.md#recording-the-demo).

## Acknowledgements

omac stands on the shoulders of two projects that inspired this build:

- **[Omarchy](https://omarchy.org)** ([basecamp/omarchy](https://github.com/basecamp/omarchy)) —
  DHH's beautiful, opinionated, keyboard-driven Arch Linux. Its themes and desktop philosophy are
  the north star omac ports to macOS.
- **[Omakos](https://github.com/yatish27/omakos)** — an opinionated, idempotent macOS dev-machine
  setup that shaped how omac approaches declarative, re-runnable Homebrew provisioning.
