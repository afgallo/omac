# Architecture

omac reproduces the parts of Omarchy that matter most on macOS — keyboard navigation, tiling,
workspaces, and one-command theming — by assembling mature macOS tools and building the one piece
that does not exist on the Mac: a theme-orchestration layer. It is **not** a Linux-distro clone;
anything macOS already does natively (disk encryption, snapshots, firewall, Touch ID, OS install)
is deliberately out of scope.

## The dispatcher

`omac` is a single entrypoint (`bin/omac`) that resolves `omac <command> [<subcommand>]` to a
script: `cmd/<command>.zsh`, or `cmd/<command>/<subcommand>.zsh` for nested commands. Each command
carries a `# help:` header that `omac help` reads. Logic lives in namespaced engines under `lib/`;
the `cmd/` scripts stay thin.

## The five modules

Independent sub-projects, each with its own spec → plan → build cycle, built in order:

1. **bootstrap** — the installer and the `omac` CLI command center; updates and migrations.
2. **software** — declarative Brewfile groups + `mise` runtimes, opt-in / opt-out.
3. **wm** — AeroSpace + SketchyBar + the global hotkey map + macOS tweaks.
4. **launcher** — Raycast: app launch, command surface, clipboard history, snippets.
5. **theme** — the orchestration layer that ports the themes and derives the macOS targets.

## Canonical paths

omac uses an XDG-on-macOS layout (a deliberate choice to mirror Omarchy and lower porting
friction — not an oversight):

| Path | Side | Role |
|---|---|---|
| `~/.local/share/omac` | repo (read-only) | scripts, defaults, themes, templates, migrations |
| `~/.config/omac` | user state | `config.zsh`, overrides, selected theme |
| `~/.config/omac/current` | user state | symlink → active theme dir |
| `~/.local/state/omac/migrations` | user state | applied-migration ledger |

## Migrations

`omac update` runs pending migrations against a ledger. Fresh installs baseline existing
migrations as applied (so a new machine never replays history), and a failed migration is skipped
into a separate ledger rather than blocking later ones.

## The theme seam

The theme layer is hybrid: **file-per-app** where Omarchy already had a themed config (dropped in
almost unchanged), and **palette-derived** for the macOS-only targets Omarchy never had (macOS
light/dark appearance, SketchyBar, Raycast, AeroSpace colors), rendered from a small `colors.toml`
palette through a templating seam. `omac theme set` repoints the `current` symlink, re-renders the
derived targets, and reloads each app.
