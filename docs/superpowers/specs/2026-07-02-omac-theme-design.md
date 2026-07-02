# omac `theme` module — design

**Status:** Approved design · **Date:** 2026-07-02 · **Parent:** `2026-06-18-omac-design.md` (module 5 of 5)

## What this is

The `theme` module is the **theme-orchestration layer** — the headline payoff of omac. It turns a
freshly installed desktop into a set of 10 switchable, fully-themed looks and makes
`omac theme set <name>` restyle everything at once: terminal, editors, topbar, TUIs, macOS
light/dark appearance, and wallpaper.

Its single responsibility is **owning colors everywhere**. `software` (module 2) installed the apps;
`wm` (module 3) deliberately shipped structure-only and left the SketchyBar `colors.sh` seam for this
module to own. `theme` sits on top and drives the palette across every app.

**Closed set, not a framework.** All 10 themes are bundled in the omac repo and ship "installed out
of the box." There is **no custom-theme flow** — no add/import/create command, no user theme
directory. `omac theme set` only ever switches among the 10 built-ins. This is a deliberate v1 scope
choice (Omarchy's "Making Your Own Theme" is out); it keeps the module a small, offline,
deterministic switcher.

## The 10 themes

Ported from `~/Code/omarchy/themes/<name>/` (the user's Omarchy checkout), macOS-relevant files only:

`tokyo-night`, `catppuccin`, `ethereal`, `everforest`, `gruvbox`, `kanagawa`, `nord`, `ristretto`,
`rose-pine` (light), `catppuccin-latte` (light).

Two are light themes (a `light.mode` marker file is present): `rose-pine`, `catppuccin-latte`.

## Goals

- `omac theme set <name>` restyles the whole desktop instantly and **offline** — no network, no
  per-theme install at switch time.
- The three targets the user relies on daily — **Ghostty, Neovim, VS Code** — work reliably for all
  10 themes ("first-class"). Everything else is best-effort: themed when a built-in exists, left at
  its default otherwise, never broken.
- All 10 themes ship bundled; `omac theme install` is a one-time wiring step that makes every theme
  switchable (pre-installs the VS Code theme extensions, points app configs at omac, sets a default).
- Idempotent and re-runnable — configs deploy through the existing diff/backup `omac::install_file`
  and marker-delimited managed blocks.
- One engine (`lib/theme.zsh`) is the single source of truth; the `cmd/theme/*` scripts are thin.
- Mirrors the `wm`/`software` module shape exactly (thin commands over one namespaced engine).

## Non-goals (v1)

- **No custom themes.** No theme authoring/import/create; no user theme directory. The set is closed
  at 10. *(Omarchy's "Making Your Own Theme" is dropped.)*
- **No window borders.** AeroSpace/JankyBorders accent borders are deferred (as `wm` already noted).
- **No Raycast palette.** Raycast's colors are deferred to v1.1; `launcher` (module 4) owns Raycast's
  Script Commands and can grow the palette later. Not a mechanism dependency.
- **No per-theme wallpaper cycling.** `set` always applies the theme's first background
  deterministically. A `theme bg` cycle command is a v1.1 follow-up.
- **No `theme next`/`random`.** Deferred to v1.1.
- **No theme installation of apps.** All casks/formulae come from `software`. The only thing `theme`
  installs is the VS Code/Cursor *theme extensions* (they are theme content, not apps).

## Mechanism classes

Every target falls into one of three classes. The preference, per the user, is **out-of-the-box
built-in themes** wherever possible; palette derivation only where nothing built-in exists.

| Class | How it themes | Targets |
|---|---|---|
| **A · Named built-in** | write a theme *name*; the app supplies the colors | Ghostty (`theme=`), VS Code/Cursor (extension + `workbench.colorTheme`), bat, git-delta |
| **B · Ported drop-in file** | reference/copy a real file the app reads | Neovim (LazyVim plugin spec), btop (`btop.theme`) |
| **C · Palette-derived** | render from `colors.toml` | SketchyBar `colors.sh`, macOS light/dark appearance, wallpaper selection |

### Reliability tiers

- **First-class (guaranteed for all 10):** **Ghostty**, **Neovim**, **VS Code**, **SketchyBar**,
  **macOS appearance**, **wallpaper**. These always apply.
  - Ghostty is class-A with a class-C fallback: use the matching built-in theme name when one exists,
    otherwise render a Ghostty config from `colors.toml` (`foreground`/`background`/`cursor`/
    `selection-*`/`palette = 0=#…`). Either way Ghostty is themed for every theme.
- **Best-effort (themed if a built-in exists, else left at default):** **Cursor** (VS Code fork; same
  mechanism, gated on the `cursor` CLI), **bat**, **git-delta**. A missing binary or missing built-in
  name skips that one target with a warning — it never aborts the switch.

> **Zed dropped (2026-07-02):** Zed ships only One Dark/Light as true built-ins (the rest are
> extensions) and has no stable install-extension CLI, so there is no out-of-the-box path to theme it
> across the set. Zed theming is out of scope; the `zed` key is removed from `apps.toml`.

## Theme storage layout (`themes/<name>/`)

The `themes/` dir is repo-side and read-only (per the master design's canonical paths). Port each
theme keeping only macOS-relevant files:

```
themes/tokyo-night/
  colors.toml        # palette (ported as-is) — feeds class-C derivation + Ghostty fallback
  neovim.lua         # LazyVim plugin spec (ported drop-in, class B)
  btop.theme         # real colors (ported drop-in, class B)
  vscode.json        # { name, extension } pointer (ported as-is, class A)
  apps.toml          # NEW — built-in theme names for the class-A best-effort targets
  light.mode         # marker; present only for rose-pine, catppuccin-latte
  backgrounds/       # wallpapers, every "omarchy"-named file removed
```

**Dropped as Linux-only / unused on macOS:** `icons.theme`, `keyboard.rgb`, `hyprland.conf`,
`waybar.css`, `chromium.theme`, `unlock.png`, `preview-unlock.png`, `preview.png`.

**Background exclusion rule:** drop any filename containing `omarchy` (case-insensitive). This removes
`omarchy.png` (every theme) and `rose-pine/backgrounds/3-omarchy-plants.png`. Filenames containing
`oma` but not the word `omarchy` are **kept** (`tokyo-night/backgrounds/4-oma-cityscape.jpg`,
`5-oma.jpg`) — they are not the word "omarchy". *(Confirm this reading at spec review.)*

### `apps.toml` (new, small)

`vscode.json`, `neovim.lua`, `btop.theme`, and `colors.toml` already carry everything the first-class
and class-B/C targets need. `apps.toml` adds only the built-in *names* for the remaining class-A
best-effort targets (Ghostty, bat, and delta), so no new format is needed for the ported files. It
uses **flat `key = "value"` lines** (not sectioned TOML) so one parser serves both `colors.toml` and
`apps.toml`:

```toml
# themes/tokyo-night/apps.toml
ghostty = "TokyoNight"   # built-in name; omitted → Ghostty renders from colors.toml
bat     = "TwoDark"      # optional; omitted → bat AND delta left at default
```

Every key is optional. A missing key means "no built-in for this theme → skip that target" (except
Ghostty, which falls back to `colors.toml` rendering). **git-delta reuses the `bat` name** — delta's
`syntax-theme` shares bat's theme namespace, so no separate `delta` key exists. The exact names are
authored during implementation and **verified against `ghostty +list-themes` and
`bat --list-themes`** — the design guarantees the *mechanism*, not a specific name string.

### VS Code / Cursor extension map (concrete, from the ported `vscode.json`)

| Theme | `workbench.colorTheme` | Extension to pre-install |
|---|---|---|
| tokyo-night | Tokyo Night | `enkia.tokyo-night` |
| catppuccin | Catppuccin Mocha | `catppuccin.catppuccin-vsc` |
| ethereal | Ethereal | `Bjarne.ethereal-omarchy` ⚠ |
| everforest | Everforest Dark | `reesew.everforest-theme` |
| gruvbox | Gruvbox Dark Medium | `jdinhlife.gruvbox` |
| kanagawa | Kanagawa | `qufiwefefwoyn.kanagawa` |
| nord | Nord | `arcticicestudio.nord-visual-studio-code` |
| ristretto | Monokai Pro (Filter Ristretto) | `monokai.theme-monokai-pro-vscode` |
| rose-pine | Rosé Pine Dawn | `mvllow.rose-pine` |
| catppuccin-latte | Catppuccin Latte | `catppuccin.catppuccin-vsc` |

⚠ The Ethereal extension **id** contains the string "omarchy" (`Bjarne.ethereal-omarchy`). The
user's "no omarchy" constraint is about wallpaper *images*; this is the real marketplace extension
that supplies the theme's colors, so it is kept. Flagged for visibility.

Two themes share one extension (`catppuccin.catppuccin-vsc`), so only the *distinct* extensions are
installed. `catppuccin`/`catppuccin-latte` differ only by `colorTheme` value.

## Two verbs: wire once (`install`), switch fast (`set`) — mirrors `wm`

### `omac theme install` — one-time wiring (idempotent, re-runnable)

Makes every bundled theme switchable. Parallel to `omac wm install`.

1. **Pre-install VS Code/Cursor theme extensions** — the distinct extension ids above, via
   `code --install-extension <id>` (and `cursor --install-extension <id>` if `cursor` exists).
   After this, every theme switch is offline. Missing `code`/`cursor` CLI → warn and skip (VS Code
   theming then no-ops until the CLI exists; the rest of the desktop still themes).
2. **Wire app configs to omac** (managed blocks / symlinks via the existing helpers):
   - **Ghostty:** ensure `~/.config/ghostty/config` includes `config-file = ~/.config/ghostty/omac-theme.conf` (`omac::ensure_block`). `set` writes `omac-theme.conf`.
   - **Neovim:** link `~/.config/nvim/lua/plugins/omac-theme.lua` → `~/.config/omac/current/neovim.lua` (LazyVim auto-loads any file under `lua/plugins/`). `set` repoints `current`.
   - **btop:** set `color_theme = "…/current/btop.theme"` in `~/.config/btop/btop.conf` (managed).
   - **SketchyBar:** already wired by `wm` (`colors.sh` is sourced by `sketchybarrc`). No action.
3. **Set the default theme** — invoke `omac theme set <default>` (default `tokyo-night`, overridable
   via `OMAC_DEFAULT_THEME`). This performs the first full application.

### `omac theme set <name>` — the switch (instant, offline)

1. **Validate** `<name>` is one of the 10; else error + `list`.
2. **Repoint** `~/.config/omac/current` → `themes/<name>` (the class-B ported files —
   `neovim.lua`, `btop.theme` — and `backgrounds/`, `colors.toml` are now reachable via `current`).
3. **Render / write class-A + class-C targets** into their app locations:
   - **Ghostty:** write `~/.config/ghostty/omac-theme.conf` — `theme = <apps.toml ghostty name>` if
     present, else a full `foreground=/background=/cursor-color=/selection-*=/palette=` block rendered
     from `colors.toml`.
   - **SketchyBar:** overwrite `~/.config/sketchybar/colors.sh` (`BAR_COLOR`/`LABEL_COLOR`/
     `ACCENT_COLOR`) rendered from `colors.toml` (`background`/`foreground`/`accent`), as the `0xAARRGGBB` format the seam uses.
   - **VS Code / Cursor:** set `workbench.colorTheme` (managed JSON edit) to the table's value; Cursor
     only if its config dir is present. **Path note:** VS Code and Cursor are *not* XDG on macOS —
     omac writes `~/Library/Application Support/{Code,Cursor}/User/settings.json`, not `~/.config`.
   - **bat:** where the `apps.toml` `bat` name is present, write an omac-managed
     `--theme="<name>"` block into `~/.config/bat/config`; else leave bat at its default.
   - **git-delta:** where the `bat` name is present, set `git config --global delta.syntax-theme
     "<name>"` (delta reuses the bat name); else leave delta at its default.
4. **macOS appearance:** if `themes/<name>/light.mode` exists → light, else dark, via
   `osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to <bool>'`. Applies live.
5. **Wallpaper:** set the desktop picture to the theme's **first** background (lowest sorted
   filename) via `osascript … set picture of every desktop to <abs path>`. Applies live.
6. **Reload what can reload live:** `sketchybar --reload`; appearance, wallpaper, and VS Code apply
   instantly. **Honest best-effort:** Ghostty, Neovim, and btop have no macOS reload hook — new
   windows / instances pick up the change; `set` prints exactly that so the user is never left
   wondering.
7. **Persist** the selection so it survives shells and is reported by `current`: write
   `OMAC_ACTIVE_THEME=<name>` into `~/.config/omac/config.zsh` via a managed block (`bin/omac` already
   sources `config.zsh`). The `current` symlink is the runtime source of truth; `config.zsh` is the
   durable record.

## Engine — `lib/theme.zsh`

All logic lives here; `cmd/theme/*` stay thin. Functions namespaced `omac::theme::<verb>`.

| Function | Behavior |
|---|---|
| `omac::theme::config_dir` | Print `${XDG_CONFIG_HOME:-$HOME/.config}` (deploy root). One place so tests redirect via `XDG_CONFIG_HOME`. |
| `omac::theme::list_names` | Print the theme dir basenames under `$OMAC_THEMES`, sorted. |
| `omac::theme::is_theme` | Return 0 if `<name>` is a bundled theme. |
| `omac::theme::is_light` | Return 0 if `themes/<name>/light.mode` exists. |
| `omac::theme::current` | Print the active theme (resolve the `current` symlink target's basename; fall back to `$OMAC_ACTIVE_THEME`). |
| `omac::theme::palette_get` | Read a key from a theme's `colors.toml` (simple `key = "value"` grep/parse; no TOML lib — pattern matches `runtimes.manifest`/`tweaks.conf` parsing). |
| `omac::theme::apps_get` | Read a flat `key = "…"` value from `apps.toml`; empty if absent. |
| `omac::theme::render_ghostty` | Write `omac-theme.conf` (built-in name or palette block). |
| `omac::theme::render_sketchybar` | Overwrite `colors.sh` from the palette. |
| `omac::theme::apply_vscode` | Managed `colorTheme` edit for VS Code + Cursor at their macOS `~/Library/Application Support/{Code,Cursor}/User/settings.json` paths (Cursor only if present). |
| `omac::theme::apply_bat` | Where the `bat` name is present, write an omac-managed `--theme="…"` block into `~/.config/bat/config`; else no-op. |
| `omac::theme::apply_delta` | Where the `bat` name is present, `git config --global delta.syntax-theme "…"`; else no-op. |
| `omac::theme::apply_appearance` | Toggle macOS dark mode from `light.mode`. |
| `omac::theme::apply_wallpaper` | Set desktop picture to the first background. |
| `omac::theme::wire` | The `install`-time managed-block/symlink wiring (Ghostty/Neovim/btop). |
| `omac::theme::install_extensions` | Pre-install the distinct VS Code/Cursor extensions. |
| `omac::theme::set` | Orchestrate the 7-step switch above. |
| `omac::theme::install` | `install_extensions` → `wire` → `set <default>`. |
| `omac::theme::reload` | Re-apply the current theme (re-run `set` for the active name) without changing selection. |
| `omac::theme::status`/`list` | Non-mutating list: each theme, `●` current, `☾` light. |

Guards: a missing app binary (`code`, `cursor`, `bat`, `git` for delta, `sketchybar`) warns and skips
that one target; it is never fatal (best-effort principle). An unknown theme name is a hard error.

## CLI surface

```
cmd/theme.zsh            # bare `omac theme` → usage + current theme; unknown subcommand → warn, return 1
cmd/theme/install.zsh    # omac theme install   → pre-install extensions + wire configs + set default
cmd/theme/set.zsh        # omac theme set <name>→ the instant offline switch
cmd/theme/list.zsh       # omac theme list      → list themes (● current, ☾ light)
cmd/theme/current.zsh    # omac theme current   → print active theme name
cmd/theme/reload.zsh     # omac theme reload    → re-apply current theme (re-render + reload)
```

### Dispatcher fit (no changes to `bin/omac`)

Identical to `wm`/`software`: `omac theme <sub>` resolves `cmd/theme/<sub>.zsh` (depth 2, token
consumed); `omac theme` (bare) falls to `cmd/theme.zsh` (depth 1) → usage; `omac theme bogus` →
`cmd/theme.zsh` with `$1=bogus` → warn + return 1. `omac theme set <name>` passes `<name>` as `$1` to
`cmd/theme/set.zsh` after the `set` token is consumed.

## Error handling

| Situation | Behavior |
|---|---|
| Unknown theme name | Hard error + `list`; non-zero. |
| `code`/`cursor` CLI missing | Warn, skip VS Code/Cursor theming; the rest of the desktop still themes. |
| `bat`/`git` (for delta)/`sketchybar` missing | Warn, skip that one target; continue. |
| No built-in name for a best-effort target | Silently leave that app at its default (documented, not an error). |
| Ghostty/Neovim/btop can't hot-reload on macOS | Not an error — `set` states new windows/instances pick it up. |
| Conflicting existing managed block / config | Handled by `omac::ensure_block` (idempotent) / `omac::install_file` (diff + backup). |
| Unknown subcommand | Usage notes it; non-zero. |

## Env overrides

Reuse the **existing `OMAC_THEMES`** already defined in `lib/paths.zsh` (default `$OMAC_HOME/themes`)
as the theme-sources root — no new sources variable is introduced (the master design reserved it and
`bootstrap` already ships it; adding a singular `OMAC_THEME` would duplicate it). Tests point
`OMAC_THEMES` at a fixture dir. Two small additions to `lib/paths.zsh`:

- `OMAC_DEFAULT_THEME` — the theme `install` applies (default `tokyo-night`).
- `OMAC_ACTIVE_THEME` — the persisted selection, written into `config.zsh` by `set`.

Deploy targets derive from `${XDG_CONFIG_HOME:-$HOME/.config}` so tests redirect via
`XDG_CONFIG_HOME`.

## Testing

Follows the existing `test_*.zsh` harness (`check`/`contains`/`finish`; fake `OMAC_HOME` from
symlinked `lib`/`bin`/`cmd` + `mktemp` dirs). Real system state must never be touched:

- **Stub** `osascript`, `sketchybar`, `code`, `cursor`, `defaults`, `open`, `bat`, `git` as scripts
  on a temp `PATH` that log their args and exit 0 (the `wm_stubs.zsh` approach; a `theme_stubs.zsh`
  helper adds these). VS Code/Cursor `settings.json` writes go to a temp
  `Library/Application Support` root the test redirects (an `OMAC_APPSUPPORT`-style seam, settled in
  the plan).
- Point **`OMAC_THEMES`** at a temp fixture theme tree (2–3 fixture themes, one with `light.mode`,
  each with a small `colors.toml`, `apps.toml`, `neovim.lua`, `btop.theme`, `vscode.json`, and a
  couple of `backgrounds/` including an `omarchy.png` to prove exclusion) and **`XDG_CONFIG_HOME`** at
  a temp deploy dir.

Assertions:

- `omac theme install` installs the distinct extensions (assert on the `code` stub log — deduped),
  wires Ghostty/Neovim/btop (managed block / symlink present), and applies the default theme.
- `omac theme set <dark>` repoints `current`, renders `omac-theme.conf` (built-in name path *and*,
  for a fixture with no `apps.toml` ghostty name, the palette-fallback path), renders `colors.sh` from
  the fixture palette, writes VS Code `colorTheme`, calls `osascript` for **dark**, and sets the
  wallpaper to the first background (assert path passed to the `osascript`/`open` stub).
- `omac theme set <light>` toggles appearance to **light** (assert the `osascript` dark-mode `false`).
- Wallpaper selection ignores any `omarchy`-named background (assert the excluded file is never the
  chosen path).
- For a fixture theme with a `bat` name, `omac theme set` writes a `--theme="…"` block into
  `~/.config/bat/config` and calls `git config --global delta.syntax-theme "…"` (assert on the file
  and the `git` stub log); a fixture with no `bat` name touches neither.
- A stubbed-missing `code` makes VS Code theming warn-and-skip without failing the switch.
- `omac theme list` marks the current theme and light themes; `omac theme current` prints the active
  name; unknown theme → non-zero; `omac theme` (bare) → usage, exit 0; `omac theme bogus` → non-zero.

## Porting task (implementation)

For each of the 10 themes, from `~/Code/omarchy/themes/<name>/` into `themes/<name>/`:

1. Copy `colors.toml`, `neovim.lua`, `btop.theme`, `vscode.json`, and `light.mode` (where present).
2. Copy `backgrounds/`, excluding every filename containing `omarchy` (case-insensitive).
3. Author `apps.toml` with verified `ghostty` and `bat` built-in names (delta reuses the `bat` name);
   omit unknowns.
4. Do **not** copy `icons.theme`, `keyboard.rgb`, `hyprland.conf`, `waybar.css`, `chromium.theme`,
   `unlock.png`, `preview-unlock.png`, `preview.png`.

## Open questions

- **Background exclusion reading** — confirm `oma-*` (not the word "omarchy") backgrounds are kept.
- **Ghostty/bat built-in name strings** — verified during implementation against each tool's theme
  list; the design fixes the mechanism, not the strings.
