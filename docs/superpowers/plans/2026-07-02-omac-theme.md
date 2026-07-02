# omac `theme` module — Implementation Plan

> **Amendment (2026-07-02):** this plan is a historical execution record. Four scope changes landed
> after it ran and are authoritative in `specs/2026-07-02-omac-theme-design.md`, superseding the
> matching parts below; a separate follow-up implementation plan carries the code:
> 1. **Zed theming dropped** — no OOB coverage + no install CLI. Remove the `zed` key from every
>    `apps.toml` and all Zed references here.
> 2. **bat implemented** — `omac::theme::apply_bat` writes a managed `--theme="<bat name>"` block into
>    `~/.config/bat/config`.
> 3. **git-delta implemented** — `omac::theme::apply_delta` runs `git config --global
>    delta.syntax-theme "<bat name>"` (delta reuses the `bat` name; no separate key).
> 4. **VS Code/Cursor path fixed** — `apply_vscode` writes
>    `~/Library/Application Support/{Code,Cursor}/User/settings.json`, NOT `~/.config`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `omac theme` module — a closed set of 10 bundled, switchable desktop themes where `omac theme set <name>` restyles Ghostty, Neovim, VS Code, btop, SketchyBar, macOS light/dark appearance, and the wallpaper at once, offline.

**Architecture:** One namespaced engine (`lib/theme.zsh`) holds all logic; thin `cmd/theme/*` scripts dispatch to it, exactly like the existing `wm`/`software` modules. Themes are bundled under `themes/<name>/` (ported from the user's Omarchy checkout). Three mechanism classes: **named built-in** (Ghostty/VS Code/Cursor/Zed/bat/delta), **ported drop-in file** (Neovim/btop), **palette-derived** (SketchyBar/appearance/wallpaper). A one-time `omac theme install` wires app configs and pre-installs the VS Code extensions; `omac theme set` is then an instant offline switch.

**Tech Stack:** zsh (pure — no python/jq/TOML libs), macOS `osascript`/`defaults`, Homebrew-installed apps (Ghostty, VS Code/Cursor, btop, SketchyBar), the existing `omac::install_file`/`omac::ensure_block`/`omac::backup_path` helpers.

## Global Constraints

- **zsh only.** No python, jq, or TOML libraries. Parse `colors.toml`/`apps.toml` with grep/sed, matching the existing `tweaks.conf`/`runtimes.manifest` parsers.
- **Apple Silicon macOS (Sonoma 14 / Sequoia 15 / Tahoe 26).** Homebrew prefix `/opt/homebrew`.
- **XDG-on-macOS paths.** Deploy targets derive from `${XDG_CONFIG_HOME:-$HOME/.config}`; theme sources from the existing `OMAC_THEMES` (default `$OMAC_HOME/themes`). Never move to `~/Library`.
- **No omarchy images.** Exclude any background filename containing `omarchy` (case-insensitive) — both at port time and defensively at runtime. `oma-*` files that are not the word "omarchy" are kept.
- **Best-effort, never fatal.** A missing app binary (`code`, `cursor`, `bat`, `sketchybar`, …) or a missing built-in name warns and skips that one target; it never aborts the switch. An unknown theme name is the only hard error in `set`.
- **Idempotent & re-runnable.** Deploy via `omac::install_file` (diff+backup) and `omac::ensure_block` (managed blocks). Mirror the `wm` module's shape: thin commands over one engine, functions namespaced `omac::theme::<verb>`.
- **Closed set of 10 themes.** No custom-theme add/import/create; no user theme directory.
- **`apps.toml` format:** flat `key = "value"` lines (NOT sectioned TOML) so one parser serves both `colors.toml` and `apps.toml`. This refines the spec's illustrative `[section]` example to a single shared parser (DRY).

## File Structure

```
lib/theme.zsh                 # the engine — all omac::theme::* logic
cmd/theme.zsh                 # bare `omac theme` → usage + current theme
cmd/theme/install.zsh         # wire apps + pre-install extensions + set default
cmd/theme/set.zsh             # omac theme set <name>
cmd/theme/list.zsh            # omac theme list
cmd/theme/current.zsh         # omac theme current
cmd/theme/reload.zsh          # omac theme reload
lib/paths.zsh                 # MODIFY: add OMAC_DEFAULT_THEME, OMAC_ACTIVE_THEME
themes/<name>/                # 10 bundled themes (ported)
test/theme_stubs.zsh          # shared stubs: osascript/code/cursor/sketchybar/defaults/open
test/test_theme_core.zsh      # Task 1
test/test_theme_render.zsh    # Task 2
test/test_theme_apply.zsh     # Task 3
test/test_theme_set.zsh       # Task 4
test/test_theme_install.zsh   # Task 5
test/test_theme_cli.zsh       # Task 6
test/test_theme_content.zsh   # Task 7
```

---

### Task 1: Engine foundation — paths, TOML parsing, theme discovery

**Files:**
- Modify: `lib/paths.zsh` (add two overrides)
- Create: `lib/theme.zsh` (foundational functions only)
- Test: `test/test_theme_core.zsh`

**Interfaces:**
- Consumes: `OMAC_THEMES`, `OMAC_CURRENT`, `OMAC_CONFIG` (already in `lib/paths.zsh`); `omac::warn` (from `lib/common.zsh`).
- Produces:
  - `omac::theme::toml_get <file> <key>` → prints the unquoted value of `key = "value"` in `<file>`; empty string + return 1 if absent.
  - `omac::theme::config_dir` → prints `${XDG_CONFIG_HOME:-$HOME/.config}`.
  - `omac::theme::list_names` → prints bundled theme basenames under `$OMAC_THEMES`, sorted, one per line.
  - `omac::theme::is_theme <name>` → return 0 if `$OMAC_THEMES/<name>` is a directory.
  - `omac::theme::is_light <name>` → return 0 if `$OMAC_THEMES/<name>/light.mode` exists.
  - `omac::theme::current` → prints active theme basename (resolve `OMAC_CURRENT` symlink, else `$OMAC_ACTIVE_THEME`); return 1 if none.

- [ ] **Step 1: Add env overrides to `lib/paths.zsh`**

Add after the existing `OMAC_TEMPLATES` line:

```zsh
: ${OMAC_DEFAULT_THEME:="tokyo-night"}
: ${OMAC_ACTIVE_THEME:=""}
```

- [ ] **Step 2: Write the failing test `test/test_theme_core.zsh`**

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

# Fixture theme tree.
export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/aaa" "$OMAC_THEMES/zzz"
print -r -- 'accent = "#7aa2f7"' >  "$OMAC_THEMES/aaa/colors.toml"
print -r -- 'background = "#1a1b26"' >> "$OMAC_THEMES/aaa/colors.toml"
: > "$OMAC_THEMES/zzz/light.mode"

# Isolate config/current.
export XDG_CONFIG_HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export OMAC_ACTIVE_THEME=""

source "$ROOT/lib/theme.zsh"

check "config_dir honors XDG" "$XDG_CONFIG_HOME" "$(omac::theme::config_dir)"
check "toml_get reads accent" "#7aa2f7" "$(omac::theme::toml_get "$OMAC_THEMES/aaa/colors.toml" accent)"
check "toml_get reads background" "#1a1b26" "$(omac::theme::toml_get "$OMAC_THEMES/aaa/colors.toml" background)"
check "toml_get missing key empty" "" "$(omac::theme::toml_get "$OMAC_THEMES/aaa/colors.toml" nope)"

check "list_names sorted" "aaa
zzz" "$(omac::theme::list_names)"
check "is_theme yes" "0" "$(omac::theme::is_theme aaa; print $?)"
check "is_theme no" "1" "$(omac::theme::is_theme nope; print $?)"
check "is_light yes" "0" "$(omac::theme::is_light zzz; print $?)"
check "is_light no" "1" "$(omac::theme::is_light aaa; print $?)"

check "current none -> 1" "1" "$(omac::theme::current; print $?)"
ln -sfn "$OMAC_THEMES/aaa" "$OMAC_CURRENT"
check "current resolves symlink" "aaa" "$(omac::theme::current)"
finish
```

- [ ] **Step 3: Run test to verify it fails**

Run: `zsh test/test_theme_core.zsh`
Expected: FAIL — `omac::theme::config_dir` / `lib/theme.zsh` not found.

- [ ] **Step 4: Write `lib/theme.zsh` foundation**

```zsh
# The theme engine: switch among the 10 bundled themes. Owns colors everywhere.
# software installs the apps; wm left the SketchyBar colors.sh seam for this.
# All logic lives here; cmd/theme/* stay thin. Functions namespaced omac::theme::*.

# Deploy root. One place so tests redirect via XDG_CONFIG_HOME.
omac::theme::config_dir() {
  print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Read `key = "value"` from a flat TOML-ish file (colors.toml / apps.toml).
# Prints the unquoted value; empty + return 1 if the key is absent.
omac::theme::toml_get() {        # <file> <key>
  local file="$1" key="$2" line
  [[ -f "$file" ]] || return 1
  line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | head -1)" || true
  [[ -n "$line" ]] || return 1
  line="${line#*=}"                       # drop `key =`
  line="${line##[[:space:]]}"             # trim leading space
  line="${line%%[[:space:]]}"             # trim trailing space
  line="${line#\"}"; line="${line%\"}"    # strip surrounding quotes
  print -r -- "$line"
}

# Print bundled theme basenames, sorted.
omac::theme::list_names() {
  setopt local_options null_glob
  local d
  for d in "$OMAC_THEMES"/*(/); do
    print -r -- "${d:t}"
  done | sort
}

omac::theme::is_theme() {        # <name>
  [[ -d "$OMAC_THEMES/$1" ]]
}

omac::theme::is_light() {        # <name>
  [[ -f "$OMAC_THEMES/$1/light.mode" ]]
}

# Active theme: resolve the current symlink, else the persisted var.
omac::theme::current() {
  if [[ -L "$OMAC_CURRENT" ]]; then
    local tgt; tgt="$(readlink "$OMAC_CURRENT")"
    print -r -- "${tgt:t}"; return 0
  fi
  if [[ -n "${OMAC_ACTIVE_THEME:-}" ]]; then
    print -r -- "$OMAC_ACTIVE_THEME"; return 0
  fi
  return 1
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `zsh test/test_theme_core.zsh`
Expected: PASS — `--- 12 passed, 0 failed ---`.

- [ ] **Step 6: Commit**

```bash
git add lib/paths.zsh lib/theme.zsh test/test_theme_core.zsh
git commit -m "feat(theme): engine foundation — paths, toml parse, theme discovery"
```

---

### Task 2: Pure renderers — Ghostty config, SketchyBar colors, wallpaper pick

**Files:**
- Modify: `lib/theme.zsh` (append renderers)
- Test: `test/test_theme_render.zsh`

**Interfaces:**
- Consumes: `omac::theme::toml_get` (Task 1).
- Produces:
  - `omac::theme::hex_to_sb <#rrggbb>` → prints `0xffrrggbb`.
  - `omac::theme::render_ghostty <name> <dest-file>` → writes a Ghostty config fragment: `theme = <apps.toml ghostty>` if that key exists, else a palette block (`foreground`/`background`/`cursor-color`/`selection-*`/`palette = N=#…`) from `colors.toml`.
  - `omac::theme::render_sketchybar <name> <dest-file>` → writes `colors.sh` (`BAR_COLOR`/`LABEL_COLOR`/`ACCENT_COLOR`) from the palette.
  - `omac::theme::first_background <name>` → prints the absolute path of the theme's first background (sorted), skipping any `omarchy`-named file; return 1 if none.

- [ ] **Step 1: Write the failing test `test/test_theme_render.zsh`**

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"

# Theme A: has a ghostty built-in name in apps.toml.
mkdir -p "$OMAC_THEMES/named/backgrounds"
cat > "$OMAC_THEMES/named/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
cursor = "#c0caf5"
selection_foreground = "#c0caf5"
selection_background = "#7aa2f7"
color0 = "#32344a"
color15 = "#acb0d0"
EOF
print -r -- 'ghostty = "tokyonight"' > "$OMAC_THEMES/named/apps.toml"
: > "$OMAC_THEMES/named/backgrounds/omarchy.png"
: > "$OMAC_THEMES/named/backgrounds/1-first.jpg"
: > "$OMAC_THEMES/named/backgrounds/2-second.jpg"

# Theme B: no apps.toml -> ghostty renders from palette.
mkdir -p "$OMAC_THEMES/palette/backgrounds"
cp "$OMAC_THEMES/named/colors.toml" "$OMAC_THEMES/palette/colors.toml"
: > "$OMAC_THEMES/palette/backgrounds/0-only.png"

source "$ROOT/lib/theme.zsh"

check "hex_to_sb" "0xff1a1b26" "$(omac::theme::hex_to_sb '#1a1b26')"

gconf="$(mktemp)"
omac::theme::render_ghostty named "$gconf"
contains "ghostty uses built-in name" "theme = tokyonight" "$(<"$gconf")"

omac::theme::render_ghostty palette "$gconf"
gout="$(<"$gconf")"
check "ghostty palette has no theme= line" "no" "$([[ "$gout" == *"theme ="* ]] && print yes || print no)"
contains "ghostty palette background" "background = 1a1b26" "$gout"
contains "ghostty palette foreground" "foreground = a9b1d6" "$gout"
contains "ghostty palette color0"     "palette = 0=#32344a" "$gout"

sb="$(mktemp)"
omac::theme::render_sketchybar named "$sb"
sbout="$(<"$sb")"
contains "sketchybar bar color"   "BAR_COLOR=0xff1a1b26"   "$sbout"
contains "sketchybar label color" "LABEL_COLOR=0xffa9b1d6" "$sbout"
contains "sketchybar accent"      "ACCENT_COLOR=0xff7aa2f7" "$sbout"

bg="$(omac::theme::first_background named)"
check "first background skips omarchy" "1-first.jpg" "${bg:t}"
bg="$(omac::theme::first_background palette)"
check "first background single" "0-only.png" "${bg:t}"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_theme_render.zsh`
Expected: FAIL — `omac::theme::hex_to_sb` not defined.

- [ ] **Step 3: Append renderers to `lib/theme.zsh`**

```zsh
# --- Renderers (pure: read a theme, write a target file) ---------------------

# #rrggbb -> 0xffrrggbb (the 0xAARRGGBB form SketchyBar's colors.sh uses).
omac::theme::hex_to_sb() {       # <#rrggbb>
  local h="${1#\#}"
  print -r -- "0xff$h"
}

# Ghostty fragment: a built-in name if apps.toml has one, else a palette block.
omac::theme::render_ghostty() {  # <name> <dest-file>
  local name="$1" dest="$2" dir="$OMAC_THEMES/$1"
  local builtin; builtin="$(omac::theme::toml_get "$dir/apps.toml" ghostty)" || builtin=""
  mkdir -p "${dest:h}"
  if [[ -n "$builtin" ]]; then
    print -r -- "theme = $builtin" > "$dest"
    return 0
  fi
  # Palette fallback — Ghostty accepts hex without '#' for fg/bg/cursor.
  local pal="$dir/colors.toml" k v i
  {
    for k in foreground background; do
      v="$(omac::theme::toml_get "$pal" "$k")" && print -r -- "$k = ${v#\#}"
    done
    v="$(omac::theme::toml_get "$pal" cursor)"               && print -r -- "cursor-color = ${v#\#}"
    v="$(omac::theme::toml_get "$pal" selection_background)" && print -r -- "selection-background = ${v#\#}"
    v="$(omac::theme::toml_get "$pal" selection_foreground)" && print -r -- "selection-foreground = ${v#\#}"
    for i in {0..15}; do
      v="$(omac::theme::toml_get "$pal" "color$i")" && print -r -- "palette = $i=$v"
    done
  } > "$dest"
}

# SketchyBar colors.sh from the palette (bar=bg, label=fg, accent=accent).
omac::theme::render_sketchybar() {   # <name> <dest-file>
  local dir="$OMAC_THEMES/$1" dest="$2" bg fg ac
  bg="$(omac::theme::toml_get "$dir/colors.toml" background)"
  fg="$(omac::theme::toml_get "$dir/colors.toml" foreground)"
  ac="$(omac::theme::toml_get "$dir/colors.toml" accent)"
  mkdir -p "${dest:h}"
  {
    print -r -- "#!/usr/bin/env bash"
    print -r -- "# omac — rendered by 'omac theme set'. Do not edit."
    print -r -- "export BAR_COLOR=$(omac::theme::hex_to_sb "$bg")"
    print -r -- "export LABEL_COLOR=$(omac::theme::hex_to_sb "$fg")"
    print -r -- "export ACCENT_COLOR=$(omac::theme::hex_to_sb "$ac")"
  } > "$dest"
}

# Absolute path of the theme's first background, skipping omarchy-named files.
omac::theme::first_background() {    # <name>
  setopt local_options null_glob
  local dir="$OMAC_THEMES/$1/backgrounds" f
  local -a files
  for f in "$dir"/*(.); do
    [[ "${f:t:l}" == *omarchy* ]] && continue
    files+=("$f")
  done
  (( ${#files} )) || return 1
  files=(${(o)files})              # sort
  print -r -- "${files[1]}"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_theme_render.zsh`
Expected: PASS — `--- 11 passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/theme.zsh test/test_theme_render.zsh
git commit -m "feat(theme): renderers for ghostty, sketchybar, wallpaper selection"
```

---

### Task 3: System appliers — appearance, wallpaper, VS Code (+ shared stubs)

**Files:**
- Create: `test/theme_stubs.zsh`
- Modify: `lib/theme.zsh` (append appliers)
- Test: `test/test_theme_apply.zsh`

**Interfaces:**
- Consumes: `omac::theme::is_light`, `omac::theme::first_background` (Tasks 1–2); `omac::warn`, `omac::info` (common).
- Produces:
  - `omac::theme::apply_appearance <name>` → `osascript` set dark mode false if the theme is light, else true.
  - `omac::theme::apply_wallpaper <name>` → `osascript` set desktop picture to the first background; warn+skip if none.
  - `omac::theme::apply_vscode <colorTheme>` → set `workbench.colorTheme` in VS Code's and Cursor's `settings.json` (create minimal file if absent; replace value if key present; insert after `{` if not). Only for editors whose settings dir exists.

- [ ] **Step 1: Create `test/theme_stubs.zsh`**

```zsh
# Shared theme test stubs: fake system binaries on PATH that log their args.
# Call _theme_stub_setup AFTER exporting OMAC_*/XDG_CONFIG_HOME. Exposes one
# <NAME>_LOG per binary (uppercased): OSASCRIPT_LOG, CODE_LOG, CURSOR_LOG,
# SKETCHYBAR_LOG, DEFAULTS_LOG, OPEN_LOG.
_theme_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export OSASCRIPT_LOG="$(mktemp)" CODE_LOG="$(mktemp)" CURSOR_LOG="$(mktemp)" \
         SKETCHYBAR_LOG="$(mktemp)" DEFAULTS_LOG="$(mktemp)" OPEN_LOG="$(mktemp)"
  local name var
  for name in osascript code cursor sketchybar defaults open; do
    var="${(U)name}_LOG"
    cat > "$dir/$name" <<SH
#!/usr/bin/env zsh
print -r -- "\$*" >> "\$$var"
exit 0
SH
    chmod +x "$dir/$name"
  done
  export PATH="$dir:$PATH"
}
```

- [ ] **Step 2: Write the failing test `test/test_theme_apply.zsh`**

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/dark/backgrounds" "$OMAC_THEMES/lite/backgrounds"
: > "$OMAC_THEMES/dark/backgrounds/omarchy.png"
: > "$OMAC_THEMES/dark/backgrounds/1-wall.jpg"
: > "$OMAC_THEMES/lite/light.mode"
: > "$OMAC_THEMES/lite/backgrounds/1-day.jpg"

export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"

omac::theme::apply_appearance dark >/dev/null 2>&1
contains "dark mode true" "set dark mode to true" "$(<"$OSASCRIPT_LOG")"
: > "$OSASCRIPT_LOG"
omac::theme::apply_appearance lite >/dev/null 2>&1
contains "light mode false" "set dark mode to false" "$(<"$OSASCRIPT_LOG")"

: > "$OSASCRIPT_LOG"
omac::theme::apply_wallpaper dark >/dev/null 2>&1
wlog="$(<"$OSASCRIPT_LOG")"
contains "wallpaper set to first bg" "1-wall.jpg" "$wlog"
check "wallpaper never omarchy" "no" "$([[ "$wlog" == *omarchy* ]] && print yes || print no)"

# VS Code: create when absent, replace when present.
vs="$XDG_CONFIG_HOME/Code/User/settings.json"
omac::theme::apply_vscode "Tokyo Night" >/dev/null 2>&1
contains "vscode created with theme" '"workbench.colorTheme": "Tokyo Night"' "$(<"$vs")"
omac::theme::apply_vscode "Nord" >/dev/null 2>&1
vsout="$(<"$vs")"
contains "vscode value replaced" '"workbench.colorTheme": "Nord"' "$vsout"
check "vscode no duplicate key" "1" "$(grep -c 'workbench.colorTheme' "$vs")"
finish
```

Note: `apply_vscode` writes to `<config_dir>/Code/User/settings.json` (and `<config_dir>/Cursor/User/settings.json`). The test only asserts the VS Code path; keep both writes guarded on the parent app dir being creatable under `config_dir`.

- [ ] **Step 3: Run test to verify it fails**

Run: `zsh test/test_theme_apply.zsh`
Expected: FAIL — `omac::theme::apply_appearance` not defined.

- [ ] **Step 4: Append appliers to `lib/theme.zsh`**

```zsh
# --- System appliers (side effects: osascript / editor settings) -------------

# macOS light/dark. Live via System Events.
omac::theme::apply_appearance() {    # <name>
  local dark=true
  omac::theme::is_light "$1" && dark=false
  omac::info "appearance: dark=$dark"
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" >/dev/null 2>&1 \
    || omac::warn "could not set appearance (System Events)"
}

# Desktop wallpaper: the theme's first (omarchy-free) background. Live.
omac::theme::apply_wallpaper() {     # <name>
  local bg; bg="$(omac::theme::first_background "$1")" || { omac::warn "no background for $1"; return 0; }
  omac::info "wallpaper: ${bg:t}"
  osascript -e "tell application \"System Events\" to set picture of every desktop to \"$bg\"" >/dev/null 2>&1 \
    || omac::warn "could not set wallpaper"
}

# Write workbench.colorTheme into one editor settings file (create/replace/insert).
omac::theme::_vscode_write() {       # <colorTheme> <settings-file>
  local name="$1" f="$2" tmp
  mkdir -p "${f:h}"
  if [[ ! -f "$f" ]]; then
    printf '{\n  "workbench.colorTheme": "%s"\n}\n' "$name" > "$f"
    return 0
  fi
  tmp="$f.omac.tmp"
  if grep -q '"workbench.colorTheme"' "$f"; then
    sed -E 's/("workbench\.colorTheme"[[:space:]]*:[[:space:]]*")[^"]*(")/\1'"$name"'\2/' "$f" > "$tmp" && mv "$tmp" "$f"
  else
    awk -v v="  \"workbench.colorTheme\": \"$name\"," '
      !done && /\{/ { print; print v; done=1; next } { print }
    ' "$f" > "$tmp" && mv "$tmp" "$f"
  fi
}

# Apply the VS Code colorTheme to VS Code and Cursor (whichever config dirs exist).
omac::theme::apply_vscode() {        # <colorTheme>
  local name="$1" cfg; cfg="$(omac::theme::config_dir)"
  omac::theme::_vscode_write "$name" "$cfg/Code/User/settings.json"
  [[ -d "$cfg/Cursor" ]] && omac::theme::_vscode_write "$name" "$cfg/Cursor/User/settings.json"
  omac::info "editor theme: $name"
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `zsh test/test_theme_apply.zsh`
Expected: PASS — `--- 8 passed, 0 failed ---`.

- [ ] **Step 6: Commit**

```bash
git add test/theme_stubs.zsh lib/theme.zsh test/test_theme_apply.zsh
git commit -m "feat(theme): system appliers — appearance, wallpaper, vscode colorTheme"
```

---

### Task 4: `set` orchestration — the switch

**Files:**
- Modify: `lib/theme.zsh` (append `set`, `persist`, `reload`)
- Test: `test/test_theme_set.zsh`

**Interfaces:**
- Consumes: everything from Tasks 1–3; `omac::error`, `omac::ok`, `omac::remove_block`, `omac::ensure_block` (common).
- Produces:
  - `omac::theme::persist <name>` → rewrite the managed `OMAC_ACTIVE_THEME` block in `$OMAC_CONFIG/config.zsh` (remove then re-add, so switching updates the value).
  - `omac::theme::set <name>` → validate; repoint `OMAC_CURRENT`; render Ghostty (`<config_dir>/ghostty/omac-theme.conf`) + SketchyBar (`<config_dir>/sketchybar/colors.sh`); apply vscode (from `vscode.json` name), appearance, wallpaper; `sketchybar --reload` if present; persist; print the best-effort reload note.
  - `omac::theme::reload` → re-run `set` for the current theme.

- [ ] **Step 1: Write the failing test `test/test_theme_set.zsh`**

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/tokyo-night/backgrounds"
cat > "$OMAC_THEMES/tokyo-night/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
color0 = "#32344a"
EOF
print -r -- 'ghostty = "tokyonight"' > "$OMAC_THEMES/tokyo-night/apps.toml"
print -r -- '{ "name": "Tokyo Night", "extension": "enkia.tokyo-night"}' > "$OMAC_THEMES/tokyo-night/vscode.json"
print -r -- 'return {}' > "$OMAC_THEMES/tokyo-night/neovim.lua"
print -r -- 'theme[main_bg]="#1a1b26"' > "$OMAC_THEMES/tokyo-night/btop.theme"
: > "$OMAC_THEMES/tokyo-night/backgrounds/1-wall.jpg"

export XDG_CONFIG_HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export HOME="$(mktemp -d)"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"

# Unknown theme -> hard error.
omac::theme::set nope >/dev/null 2>&1
check "unknown theme exits 1" "1" "$?"

# Real switch.
omac::theme::set tokyo-night >/dev/null 2>&1
check "set exits 0" "0" "$?"
check "current symlink points at theme" "tokyo-night" "${$(readlink "$OMAC_CURRENT"):t}"
present="$([[ -f "$XDG_CONFIG_HOME/ghostty/omac-theme.conf" ]] && print yes || print no)"
check "ghostty fragment written" "yes" "$present"
contains "ghostty theme name" "theme = tokyonight" "$(<"$XDG_CONFIG_HOME/ghostty/omac-theme.conf")"
contains "sketchybar rendered" "BAR_COLOR=0xff1a1b26" "$(<"$XDG_CONFIG_HOME/sketchybar/colors.sh")"
contains "vscode colorTheme from vscode.json" "Tokyo Night" "$(<"$XDG_CONFIG_HOME/Code/User/settings.json")"
contains "appearance applied" "set dark mode to true" "$(<"$OSASCRIPT_LOG")"
contains "wallpaper applied" "1-wall.jpg" "$(<"$OSASCRIPT_LOG")"
contains "sketchybar reloaded" "--reload" "$(<"$SKETCHYBAR_LOG")"
contains "selection persisted" 'OMAC_ACTIVE_THEME="tokyo-night"' "$(<"$OMAC_CONFIG/config.zsh")"

# Switching again updates the persisted value (no duplicate).
mkdir -p "$OMAC_THEMES/nord/backgrounds"; cp "$OMAC_THEMES/tokyo-night/colors.toml" "$OMAC_THEMES/nord/colors.toml"
print -r -- '{ "name": "Nord", "extension": "x"}' > "$OMAC_THEMES/nord/vscode.json"
: > "$OMAC_THEMES/nord/backgrounds/1-w.jpg"
omac::theme::set nord >/dev/null 2>&1
check "persist single line after re-set" "1" "$(grep -c OMAC_ACTIVE_THEME "$OMAC_CONFIG/config.zsh")"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_theme_set.zsh`
Expected: FAIL — `omac::theme::set` not defined.

- [ ] **Step 3: Append `set`/`persist`/`reload` to `lib/theme.zsh`**

```zsh
# --- Orchestration -----------------------------------------------------------

# Rewrite the managed OMAC_ACTIVE_THEME block in config.zsh (update-safe:
# remove then re-add, since ensure_block alone won't change an existing value).
omac::theme::persist() {         # <name>
  local file="$OMAC_CONFIG/config.zsh"
  omac::remove_block "$file"
  omac::ensure_block "$file" "export OMAC_ACTIVE_THEME=\"$1\""
}

# The switch: validate, repoint current, render/apply every target, persist.
omac::theme::set() {             # <name>
  local name="$1"
  if [[ -z "$name" ]] || ! omac::theme::is_theme "$name"; then
    omac::error "unknown theme: ${name:-<none>}"
    omac::theme::list_names
    return 1
  fi
  local cfg; cfg="$(omac::theme::config_dir)"

  # 1. Repoint the current symlink (class-B ported files reachable via current).
  mkdir -p "$OMAC_CONFIG"
  ln -sfn "$OMAC_THEMES/$name" "$OMAC_CURRENT"

  # 2. Render class-A/C targets into their app locations.
  omac::theme::render_ghostty "$name" "$cfg/ghostty/omac-theme.conf"
  omac::theme::render_sketchybar "$name" "$cfg/sketchybar/colors.sh"

  # 3. Editors (best-effort): VS Code colorTheme from the theme's vscode.json.
  local ct; ct="$(omac::theme::toml_get "$OMAC_THEMES/$name/vscode.json" name)" || ct=""
  [[ -n "$ct" ]] && omac::theme::apply_vscode "$ct"

  # 4-5. Appearance + wallpaper.
  omac::theme::apply_appearance "$name"
  omac::theme::apply_wallpaper "$name"

  # 6. Reload what can reload live.
  command -v sketchybar >/dev/null 2>&1 && sketchybar --reload >/dev/null 2>&1

  # 7. Persist.
  omac::theme::persist "$name"

  omac::ok "theme set: $name"
  omac::info "Ghostty, Neovim, and btop apply on the next new window/instance"
}

# Re-apply the current theme (re-render + reload) without changing the selection.
omac::theme::reload() {
  local name; name="$(omac::theme::current)" || { omac::error "no active theme"; return 1; }
  omac::theme::set "$name"
}
```

Note: `vscode.json` is JSON, but its `"name": "..."` line matches the same `key = "value"`-ish shape closely enough for `toml_get`? No — JSON uses `"name": "value"`, not `name = "value"`. Use a JSON-aware read here instead: change step 3 to parse the JSON `name` field. Replace the `ct=` line with:

```zsh
  local ct; ct="$(grep -E '"name"[[:space:]]*:' "$OMAC_THEMES/$name/vscode.json" 2>/dev/null \
                  | head -1 | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_theme_set.zsh`
Expected: PASS — `--- 13 passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/theme.zsh test/test_theme_set.zsh
git commit -m "feat(theme): set orchestration — switch, persist, reload"
```

---

### Task 5: `install` wiring — extensions + app configs + default

**Files:**
- Modify: `lib/theme.zsh` (append `install_extensions`, `wire`, `install`)
- Test: `test/test_theme_install.zsh`

**Interfaces:**
- Consumes: everything above; `omac::ensure_block`, `omac::info`, `omac::ok`, `omac::warn`.
- Produces:
  - `omac::theme::install_extensions` → for each distinct `extension` id across all `themes/*/vscode.json`, run `code --install-extension <id>` (and `cursor --install-extension <id>` if `cursor` exists). Missing `code` → warn+skip.
  - `omac::theme::wire` → ensure Ghostty `config-file` include, symlink the Neovim plugin pointer, set btop `color_theme` (all idempotent, via managed blocks / symlink into `OMAC_CURRENT`).
  - `omac::theme::install` → `install_extensions` → `wire` → `set "$OMAC_DEFAULT_THEME"`.

- [ ] **Step 1: Write the failing test `test/test_theme_install.zsh`**

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
# Two themes; one extension shared -> must dedupe.
for t in tokyo-night catppuccin; do
  mkdir -p "$OMAC_THEMES/$t/backgrounds"
  cat > "$OMAC_THEMES/$t/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
EOF
  print -r -- 'return {}' > "$OMAC_THEMES/$t/neovim.lua"
  print -r -- 'theme[main_bg]="#000000"' > "$OMAC_THEMES/$t/btop.theme"
  : > "$OMAC_THEMES/$t/backgrounds/1-w.jpg"
done
print -r -- '{ "name": "Tokyo Night", "extension": "enkia.tokyo-night"}' > "$OMAC_THEMES/tokyo-night/vscode.json"
print -r -- '{ "name": "Catppuccin Mocha", "extension": "catppuccin.catppuccin-vsc"}' > "$OMAC_THEMES/catppuccin/vscode.json"

export XDG_CONFIG_HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export OMAC_DEFAULT_THEME="tokyo-night"
export HOME="$(mktemp -d)"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"

omac::theme::install_extensions >/dev/null 2>&1
clog="$(<"$CODE_LOG")"
contains "installs tokyo ext"      "install-extension enkia.tokyo-night" "$clog"
contains "installs catppuccin ext" "install-extension catppuccin.catppuccin-vsc" "$clog"
check "extensions deduped (2 distinct)" "2" "$(grep -c install-extension "$CODE_LOG")"

omac::theme::wire >/dev/null 2>&1
contains "ghostty include wired" "config-file" "$(<"$XDG_CONFIG_HOME/ghostty/config")"
present="$([[ -L "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-theme.lua" ]] && print yes || print no)"
check "neovim plugin pointer linked" "yes" "$present"
contains "btop color_theme set" "color_theme" "$(<"$XDG_CONFIG_HOME/btop/btop.conf")"

omac::theme::install >/dev/null 2>&1
check "install exits 0" "0" "$?"
check "install set default (current)" "tokyo-night" "${$(readlink "$OMAC_CURRENT"):t}"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_theme_install.zsh`
Expected: FAIL — `omac::theme::install_extensions` not defined.

- [ ] **Step 3: Append `install_extensions`/`wire`/`install` to `lib/theme.zsh`**

```zsh
# --- One-time wiring (install) -----------------------------------------------

# Pre-install the distinct VS Code/Cursor theme extensions across all themes.
omac::theme::install_extensions() {
  setopt local_options null_glob
  local -a ids; local f id
  for f in "$OMAC_THEMES"/*/vscode.json; do
    id="$(grep -E '"extension"[[:space:]]*:' "$f" 2>/dev/null \
          | head -1 | sed -E 's/.*"extension"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
    [[ -n "$id" ]] && ids+=("$id")
  done
  ids=(${(u)ids})                 # dedupe
  if ! command -v code >/dev/null 2>&1; then
    omac::warn "no 'code' CLI — skipping VS Code extension pre-install"
    return 0
  fi
  for id in $ids; do
    omac::info "installing extension: $id"
    code --install-extension "$id" >/dev/null 2>&1 || omac::warn "failed: $id"
    command -v cursor >/dev/null 2>&1 && cursor --install-extension "$id" >/dev/null 2>&1
  done
}

# Point the user's real app configs at omac (idempotent managed blocks/symlink).
omac::theme::wire() {
  local cfg; cfg="$(omac::theme::config_dir)"
  omac::ensure_block "$cfg/ghostty/config" "config-file = $cfg/ghostty/omac-theme.conf"
  mkdir -p "$cfg/nvim/lua/plugins"
  ln -sfn "$OMAC_CURRENT/neovim.lua" "$cfg/nvim/lua/plugins/omac-theme.lua"
  omac::ensure_block "$cfg/btop/btop.conf" "color_theme = \"$OMAC_CURRENT/btop.theme\""
  omac::ok "wired ghostty, neovim, btop"
}

# Full first-run: extensions, wiring, then apply the default theme.
omac::theme::install() {
  omac::theme::install_extensions
  omac::theme::wire
  omac::theme::set "$OMAC_DEFAULT_THEME"
  omac::ok "theme installed (default: $OMAC_DEFAULT_THEME)"
}
```

Note: `btop.conf`'s comment character is `#`, so `omac::ensure_block`'s `# >>> omac >>>` markers are valid there. Ghostty config also uses `#` comments — valid. Both safe.

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_theme_install.zsh`
Expected: PASS — `--- 8 passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/theme.zsh test/test_theme_install.zsh
git commit -m "feat(theme): install wiring — extensions, app configs, default theme"
```

---

### Task 6: CLI command scripts

**Files:**
- Create: `cmd/theme.zsh`, `cmd/theme/install.zsh`, `cmd/theme/set.zsh`, `cmd/theme/list.zsh`, `cmd/theme/current.zsh`, `cmd/theme/reload.zsh`
- Test: `test/test_theme_cli.zsh`

**Interfaces:**
- Consumes: the whole engine; `bin/omac` dispatcher (already supports depth-2 resolution — no change).
- Produces: the `omac theme …` user surface.

- [ ] **Step 1: Write the failing test `test/test_theme_cli.zsh`**

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"

fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"; ln -s "$ROOT/bin" "$fake/bin"; ln -s "$ROOT/cmd" "$fake/cmd"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
export OMAC_DEFAULT_THEME="tokyo-night"

export OMAC_THEMES="$(mktemp -d)/themes"
for t in tokyo-night nord; do
  mkdir -p "$OMAC_THEMES/$t/backgrounds"
  cat > "$OMAC_THEMES/$t/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
EOF
  print -r -- 'return {}' > "$OMAC_THEMES/$t/neovim.lua"
  print -r -- 'x' > "$OMAC_THEMES/$t/btop.theme"
  print -r -- "{ \"name\": \"$t\", \"extension\": \"e.$t\"}" > "$OMAC_THEMES/$t/vscode.json"
  : > "$OMAC_THEMES/$t/backgrounds/1-w.jpg"
done
: > "$OMAC_THEMES/nord/light.mode"
_theme_stub_setup

bare="$(zsh "$fake/bin/omac" theme)"
contains "bare prints usage"   "Usage" "$bare"
contains "bare mentions set"   "set"   "$bare"

zsh "$fake/bin/omac" theme bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

zsh "$fake/bin/omac" theme set tokyo-night >/dev/null 2>&1
check "set exits 0" "0" "$?"
check "current reports theme" "tokyo-night" "$(zsh "$fake/bin/omac" theme current)"

listout="$(zsh "$fake/bin/omac" theme list)"
contains "list shows tokyo-night" "tokyo-night" "$listout"
contains "list marks current"     "tokyo-night" "$listout"
contains "list shows nord"        "nord"        "$listout"

zsh "$fake/bin/omac" theme reload >/dev/null 2>&1
check "reload exits 0" "0" "$?"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_theme_cli.zsh`
Expected: FAIL — no `cmd/theme.zsh`, dispatcher errors.

- [ ] **Step 3: Create the command scripts**

`cmd/theme.zsh`:
```zsh
# help: switch among the bundled themes (terminal, editor, topbar, wallpaper)
source "$OMAC_HOME/lib/theme.zsh"
print -r -- "omac theme — switch the desktop theme"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac theme install       wire apps, pre-install extensions, set default"
print -r -- "  omac theme set <name>    switch to a bundled theme"
print -r -- "  omac theme list          list bundled themes (● current, ☾ light)"
print -r -- "  omac theme current       print the active theme"
print -r -- "  omac theme reload        re-apply the current theme"
if cur="$(omac::theme::current 2>/dev/null)"; then
  print -r -- ""
  print -r -- "Current: $cur"
fi
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
```

`cmd/theme/install.zsh`:
```zsh
# help: wire apps, pre-install extensions, and apply the default theme
source "$OMAC_HOME/lib/theme.zsh"
omac::theme::install
```

`cmd/theme/set.zsh`:
```zsh
# help: switch to a bundled theme — omac theme set <name>
source "$OMAC_HOME/lib/theme.zsh"
if [[ -z "${1:-}" ]]; then
  omac::error "usage: omac theme set <name>"
  omac::theme::list_names
  return 1
fi
omac::theme::set "$1"
```

`cmd/theme/list.zsh`:
```zsh
# help: list bundled themes (● current, ☾ light)
source "$OMAC_HOME/lib/theme.zsh"
cur="$(omac::theme::current 2>/dev/null)" || cur=""
for t in $(omac::theme::list_names); do
  mark=" "; [[ "$t" == "$cur" ]] && mark="●"
  tag="";  omac::theme::is_light "$t" && tag=" ☾"
  print -r -- "$mark $t$tag"
done
return 0
```

`cmd/theme/current.zsh`:
```zsh
# help: print the active theme name
source "$OMAC_HOME/lib/theme.zsh"
omac::theme::current || { omac::warn "no active theme"; return 1; }
```

`cmd/theme/reload.zsh`:
```zsh
# help: re-apply the current theme (re-render + reload)
source "$OMAC_HOME/lib/theme.zsh"
omac::theme::reload
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_theme_cli.zsh`
Expected: PASS — `--- 9 passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add cmd/theme.zsh cmd/theme test/test_theme_cli.zsh
git commit -m "feat(theme): CLI — install/set/list/current/reload"
```

---

### Task 7: Port the 10 themes + content test

**Files:**
- Create: `themes/<name>/…` for all 10 themes (data)
- Test: `test/test_theme_content.zsh`

**Interfaces:**
- Consumes: `lib/theme.zsh` (`list_names`, `toml_get`, `first_background`) to validate the bundled data.
- Produces: the shipped `themes/` tree the whole module operates on.

Source: `~/Code/omarchy/themes/<name>/`. The 10 names: `tokyo-night catppuccin ethereal everforest gruvbox kanagawa nord ristretto rose-pine catppuccin-latte`.

- [ ] **Step 1: Port files with a one-shot script (run once, not committed)**

Run this from the repo root. It copies only the macOS-relevant files and drops every `omarchy`-named background.

```bash
SRC=~/Code/omarchy/themes
for t in tokyo-night catppuccin ethereal everforest gruvbox kanagawa nord ristretto rose-pine catppuccin-latte; do
  mkdir -p "themes/$t/backgrounds"
  for f in colors.toml neovim.lua btop.theme vscode.json light.mode; do
    [ -f "$SRC/$t/$f" ] && cp "$SRC/$t/$f" "themes/$t/$f"
  done
  for bg in "$SRC/$t/backgrounds"/*; do
    base=$(basename "$bg")
    case "$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')" in
      *omarchy*) ;;                      # skip omarchy-named images
      *) cp "$bg" "themes/$t/backgrounds/$base" ;;
    esac
  done
done
```

- [ ] **Step 2: Verify no omarchy images slipped through**

Run: `find themes -iname '*omarchy*'`
Expected: no output.

- [ ] **Step 3: Author `apps.toml` for each theme (built-in names)**

For each theme create `themes/<name>/apps.toml` with the flat keys below. **Verify each `ghostty` name against `ghostty +list-themes` and each `bat` name against `bat --list-themes`** before writing; if a tool has no matching built-in, **omit that key** (Ghostty then renders from the palette; bat/zed/delta stay default). Starting map (verify, then adjust casing/spelling to the tool's exact string):

```
tokyo-night      → ghostty = "TokyoNight"          zed = "Tokyo Night"        bat = "TwoDark"
catppuccin       → ghostty = "Catppuccin Mocha"    zed = "Catppuccin Mocha"   bat = "base16"
ethereal         → (omit ghostty → palette)         (omit zed/bat)
everforest       → ghostty = "Everforest Dark Hard" bat = "gruvbox-dark"
gruvbox          → ghostty = "GruvboxDark"          zed = "Gruvbox Dark"       bat = "gruvbox-dark"
kanagawa         → ghostty = "Kanagawa Wave"        bat = "Nord"
nord             → ghostty = "nord"                 zed = "Nord"               bat = "Nord"
ristretto        → ghostty = "Monokai Pro Ristretto"                            bat = "Monokai Extended"
rose-pine        → ghostty = "rose-pine-dawn"       zed = "Rosé Pine Dawn"     bat = "ansi"
catppuccin-latte → ghostty = "Catppuccin Latte"     zed = "Catppuccin Latte"   bat = "GitHub"
```

Example — `themes/tokyo-night/apps.toml`:
```toml
ghostty = "TokyoNight"
zed = "Tokyo Night"
bat = "TwoDark"
```

- [ ] **Step 4: Write the content test `test/test_theme_content.zsh`**

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"
export OMAC_THEMES="$ROOT/themes"
source "$ROOT/lib/theme.zsh"

want=(tokyo-night catppuccin ethereal everforest gruvbox kanagawa nord ristretto rose-pine catppuccin-latte)
got="$(omac::theme::list_names | tr '\n' ' ')"
for t in $want; do
  contains "theme present: $t" "$t" "$got"
  check "$t has colors.toml" "yes" "$([[ -f "$ROOT/themes/$t/colors.toml" ]] && print yes || print no)"
  check "$t has neovim.lua"  "yes" "$([[ -f "$ROOT/themes/$t/neovim.lua" ]] && print yes || print no)"
  check "$t has btop.theme"  "yes" "$([[ -f "$ROOT/themes/$t/btop.theme" ]] && print yes || print no)"
  check "$t has vscode.json" "yes" "$([[ -f "$ROOT/themes/$t/vscode.json" ]] && print yes || print no)"
  check "$t palette parses"  "no"  "$([[ -z "$(omac::theme::toml_get "$ROOT/themes/$t/colors.toml" background)" ]] && print yes || print no)"
  check "$t has a background" "0"  "$(omac::theme::first_background "$t" >/dev/null; print $?)"
done
check "rose-pine is light"       "0" "$(omac::theme::is_light rose-pine; print $?)"
check "catppuccin-latte is light" "0" "$(omac::theme::is_light catppuccin-latte; print $?)"
check "no omarchy backgrounds" "" "$(find "$ROOT/themes" -iname '*omarchy*')"
finish
```

- [ ] **Step 5: Run the content test**

Run: `zsh test/test_theme_content.zsh`
Expected: PASS (all themes present, palettes parse, no omarchy images).

- [ ] **Step 6: Run the whole suite**

Run: `zsh test/run.zsh`
Expected: every `test_*.zsh` passes, including the six new theme tests.

- [ ] **Step 7: Commit**

```bash
git add themes test/test_theme_content.zsh
git commit -m "feat(theme): bundle the 10 ported themes + content test"
```

---

## Self-Review

**Spec coverage:**
- 10 bundled themes, closed set → Task 7 (port) + content test; no add/import command anywhere → covered.
- Three mechanism classes → Ghostty/SketchyBar/wallpaper renderers (Task 2), appearance/vscode appliers (Task 3), ported neovim/btop wired (Task 5), Ghostty built-in-or-palette (Task 2) → covered.
- First-class targets always apply; best-effort skip on missing binary → guards in Tasks 3/5 (`command -v`), `apply_vscode` guarded on dir; `set` never aborts on those → covered.
- `install` (extensions + wire + default) vs `set` (instant switch) → Tasks 4–5 → covered.
- macOS light/dark from `light.mode` → Task 3 `apply_appearance` + Task 7 markers → covered.
- Wallpaper = first background, omarchy-excluded → Task 2 `first_background` (runtime filter) + Task 7 (port-time exclusion) → covered.
- Persist selection (updates on re-set) → Task 4 `persist` (remove+ensure block) → covered.
- CLI `install/set/list/current/reload` + bare usage + unknown-subcommand nonzero → Task 6 → covered.
- Reuse existing `OMAC_THEMES`; add `OMAC_DEFAULT_THEME`/`OMAC_ACTIVE_THEME` → Task 1 → covered.
- Testing with stubs + `OMAC_THEMES`/`XDG_CONFIG_HOME` fixtures → every task → covered.
- Deferred (borders, Raycast palette, `theme next`/`bg`) → correctly absent.

**Placeholder scan:** No TBD/TODO/"handle errors" — every code step has complete code. Task 7 Step 3 lists concrete starter names with an explicit "verify against `ghostty +list-themes`/`bat --list-themes`, omit if none" rule (mechanism guarantees correctness regardless of the exact string), which the spec designated as an implementation-time verification, not a placeholder.

**Type consistency:** Function names are stable across tasks — `omac::theme::{toml_get,config_dir,list_names,is_theme,is_light,current,hex_to_sb,render_ghostty,render_sketchybar,first_background,apply_appearance,apply_wallpaper,apply_vscode,_vscode_write,persist,set,reload,install_extensions,wire,install}`. `set` consumes exactly the renderers/appliers defined earlier; `install` consumes `set`; CLI consumes the engine. VS Code color name is read from `vscode.json` via a JSON-specific grep (Task 4 note), not the flat `toml_get` — corrected in the plan.
