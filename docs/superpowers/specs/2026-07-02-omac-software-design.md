# omac `software` module — design

**Status:** Approved design · **Date:** 2026-07-02 · **Parent:** `2026-06-18-omac-design.md` (module 2 of 5)

## What this is

The `software` module is the declarative, opt-in package layer for omac. It turns "install my
tools" into curated, re-runnable manifests grouped by purpose, driven through a small `omac
software` CLI. Its single responsibility is **installing packages** — Homebrew formulae/casks and
mise-managed language runtimes. It deliberately does **not** configure those packages; the `wm`,
`launcher`, and `theme` modules own configuration and reload.

## Goals

- `omac software install` provisions the full "day-one rice" on a fresh machine with no config.
- `omac software install <group>` installs exactly one group on demand.
- `omac software list` shows every group, its contents, and installed/missing status.
- Idempotent and re-runnable — leans on `brew bundle` and `mise use` idempotency.
- Adding a group is adding a file: groups are discovered by scanning the manifests directory.
- One engine (`lib/software.zsh`) is the single source of truth; `omac update` calls into it.

## Non-goals (v1)

- **No config-based selection layer.** Selection is CLI-scoped only (all groups, or a named group).
  A persistent enable/disable array can be added later without changing the manifest format.
- **No per-group upgrade command** — `omac update` already runs `brew upgrade`.
- **No removal command** — `brew bundle cleanup` is global and risky; out of scope.
- **No configuration of installed apps** — owned by later modules.

## Layout

```
software/
  groups/
    shell.Brewfile
    tuis.Brewfile
    ides.Brewfile
    ai.Brewfile
    guis.Brewfile
    fonts.Brewfile
  runtimes.manifest
lib/software.zsh            # the engine — all brew/mise logic lives here
cmd/software.zsh            # bare `omac software` → usage
cmd/software/install.zsh    # omac software install [group]
cmd/software/list.zsh       # omac software list
```

### Dispatcher fit (no changes to `bin/omac`)

The existing resolver in `bin/omac` already supports this shape:

- `omac software install shell` → `omac::resolve software install` matches `cmd/software/install.zsh`
  (depth 2); the dispatcher consumes the `install` token, leaving `$1=shell` for the script.
- `omac software install` → same script, no args → install all groups.
- `omac software list` → `cmd/software/list.zsh`.
- `omac software` (bare) → `b` is empty, so the depth-2 branch is skipped and the resolver falls to
  `cmd/software.zsh` (depth 1), which prints usage.
- `omac software bogus` → no `cmd/software/bogus.zsh`, falls to `cmd/software.zsh` with `$1=bogus`;
  usage script notes the unknown subcommand.

`cmd/software.zsh` (flat) and `cmd/software/` (nested) coexist intentionally — the resolver is built
for exactly this.

## The engine — `lib/software.zsh`

All package logic lives here so both the `cmd/software/*` scripts and `cmd/update.zsh` share it.

| Function | Behavior |
|---|---|
| `omac::software::groups` | Print group names: every `software/groups/*.Brewfile` basename, plus the special `runtimes`. Dynamic — no hardcoded list. |
| `omac::software::group_file <g>` | Print the absolute Brewfile path for a group (used by install + status). |
| `omac::software::install_group <g>` | `runtimes` → `install_runtimes`; otherwise `brew bundle --file "$(group_file g)"`. Returns brew's/mise's exit status. |
| `omac::software::install_all` | Iterate `groups`; run each `install_group`; **continue on failure**; print a per-group summary; return non-zero if any group failed. |
| `omac::software::install_runtimes` | Ensure `mise` present (`brew install mise` if missing); read `runtimes.manifest` (skip blank/`#` lines); apply all entries in one `mise use -g <entries…>` call (records + installs pinned versions). |
| `omac::software::group_status <g>` | Non-mutating. Brewfile groups → `brew bundle check --file …` → `satisfied`/`missing`. `runtimes` → check `mise` present + each manifest tool resolvable. |

Guards: a missing `brew` is a hard error with guidance to run `omac install` / open a new shell; an
unknown group is a hard error that lists valid group names.

## Manifest formats

**Group Brewfiles** are ordinary Brewfiles (`tap`, `brew`, `cask` lines) — nothing omac-specific, so
they can be edited and even `brew bundle`-ed by hand. **`runtimes.manifest`** is one mise tool spec
per line; blank lines and `#` comments ignored.

## Curated seed content

All Homebrew identifiers below were verified against a live `brew` at spec time — every active line
installs cleanly; none are placeholders.

### `shell.Brewfile`
```ruby
brew "fzf"
brew "zoxide"
brew "ripgrep"
brew "bat"
brew "eza"
brew "fd"
brew "git-delta"
brew "starship"
```

### `tuis.Brewfile`
```ruby
brew "lazygit"
brew "lazydocker"
brew "btop"
brew "pgcli"
```

### `ides.Brewfile`
```ruby
cask "visual-studio-code"
cask "cursor"
cask "zed"
```

### `ai.Brewfile`
```ruby
brew "claude-code"
brew "opencode"
cask "lm-studio"
```

### `guis.Brewfile`
```ruby
# user apps
cask "obsidian"
cask "lastpass"
cask "typora"
cask "localsend"
cask "mpv"
cask "pixelmator-pro"

# desktop environment (installed here; configured by the wm/launcher/theme modules)
cask "ghostty"                          # canonical / default terminal
cask "raycast"
tap  "nikitabobko/tap"
cask "nikitabobko/tap/aerospace"
tap  "FelixKratz/formulae"
brew "FelixKratz/formulae/sketchybar"
```

### `fonts.Brewfile`
```ruby
cask "font-jetbrains-mono-nerd-font"
cask "font-fira-code-nerd-font"
cask "font-hack-nerd-font"
cask "font-caskaydia-cove-nerd-font"
```

### `runtimes.manifest`
```
node@lts
python@3.13
go@1.24
ruby@3.4
bun@latest
deno@latest
```

### Two deliberate decisions

1. **Desktop-environment casks (ghostty, raycast, aerospace, sketchybar) live in `guis`**, not a new
   group. This keeps *all* package installation inside `software` (its single responsibility) while
   the `wm`/`launcher`/`theme` modules remain pure configuration layers. A comment header separates
   "user apps" from "desktop environment" within the file. This is a small, justified refinement of
   the parent design's group taxonomy, which listed these tools under the modules that *configure*
   them.
2. **Ghostty is the default terminal** and is present in `guis`.

## `cmd/update.zsh` reconciliation

`cmd/update.zsh` currently runs `brew bundle --file="$OMAC_HOME/Brewfile"` against a root Brewfile
that does not exist. That block is replaced by sourcing `lib/software.zsh` and calling
`omac::software::install_all`, guarded on `brew` being present and kept **non-fatal** (warn and
continue) exactly like today. The software engine becomes the single source of truth for "what gets
installed," so `omac update` and `omac software install` never drift.

## Error handling

| Situation | Behavior |
|---|---|
| `brew` missing | Hard error with guidance (`omac install` / open new shell); non-zero. |
| Unknown group | Hard error listing valid group names; non-zero. |
| Single group `brew bundle` fails | Propagate brew's non-zero status. |
| `install_all` with some groups failing | Continue remaining groups, print summary, return non-zero. |
| `runtimes` and `mise` missing | Bootstrap via `brew install mise`; if `brew` also missing, hard error. |
| Called from `omac update` | Non-fatal — warn and continue the rest of update. |

## Testing

Tests follow the existing `test_*.zsh` pattern (`check`/`contains`/`finish`, fake `OMAC_HOME` from
symlinked `lib`/`bin`/`cmd` + `mktemp` dirs). Real network/brew/mise must never be hit:

- **Stub `brew` and `mise`** as scripts on a temp dir prepended to `PATH` that append their arguments
  to a log file and exit 0.
- Point the engine at a **temp `software/` dir** with small sample group files + a sample
  `runtimes.manifest` (via an `OMAC_SOFTWARE` path override, defaulting to `$OMAC_HOME/software`).

Assertions:

- `omac software list` prints every sample group name and a status token.
- `omac software install shell` logs `brew bundle --file …/shell.Brewfile`.
- `omac software install` logs a `brew bundle` invocation for every Brewfile group.
- `omac software install runtimes` logs `mise use -g` containing the manifest entries.
- `omac software install bogus` → non-zero, error names valid groups.
- `omac software` (bare) → prints usage, exit 0.
- `omac update` invokes the engine (extend/adjust `test_update.zsh`: stubbed `brew bundle` is called
  via `install_all`, and update still reports completion).

## New env override

`OMAC_SOFTWARE` — root of the manifests dir, default `$OMAC_HOME/software`. Added to `lib/paths.zsh`
alongside the existing overrides so tests can point at a fixture dir. No user-facing config change.

## Open questions

None. Package-selection tweaks are expected over time but do not affect the mechanism.
