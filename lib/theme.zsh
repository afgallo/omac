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

# VS Code/Cursor settings root. NOT XDG on macOS — they read ~/Library/Application Support.
# One place so tests redirect via OMAC_APPSUPPORT.
omac::theme::appsupport_dir() {
  print -r -- "$OMAC_APPSUPPORT"
}

# Apply the VS Code colorTheme to VS Code and Cursor (whichever config dirs exist).
omac::theme::apply_vscode() {        # <colorTheme>
  local name="$1" as; as="$(omac::theme::appsupport_dir)"
  omac::theme::_vscode_write "$name" "$as/Code/User/settings.json"
  [[ -d "$as/Cursor" ]] && omac::theme::_vscode_write "$name" "$as/Cursor/User/settings.json"
  omac::info "editor theme: $name"
}

# bat: write a managed --theme block into ~/.config/bat/config when the theme
# names a bat built-in; no-op otherwise. Best-effort (needs the `bat` CLI).
omac::theme::apply_bat() {           # <name>
  local theme; theme="$(omac::theme::toml_get "$OMAC_THEMES/$1/apps.toml" bat)" || return 0
  [[ -n "$theme" ]] || return 0
  if ! command -v bat >/dev/null 2>&1; then
    omac::warn "no 'bat' — skipping bat theme"; return 0
  fi
  local f; f="$(omac::theme::config_dir)/bat/config"
  mkdir -p "${f:h}"
  omac::remove_block "$f"
  omac::ensure_block "$f" "--theme=\"$theme\""
  omac::info "bat theme: $theme"
}

# git-delta: reuse the theme's bat name as delta's syntax-theme (shared
# namespace). No-op when unnamed; best-effort (needs `git`).
omac::theme::apply_delta() {         # <name>
  local theme; theme="$(omac::theme::toml_get "$OMAC_THEMES/$1/apps.toml" bat)" || return 0
  [[ -n "$theme" ]] || return 0
  if ! command -v git >/dev/null 2>&1; then
    omac::warn "no 'git' — skipping delta theme"; return 0
  fi
  git config --global delta.syntax-theme "$theme" 2>/dev/null \
    || omac::warn "could not set delta syntax-theme"
  omac::info "delta syntax-theme: $theme"
}

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
  #    vscode.json is JSON ("name": "..."), so read it JSON-aware, not via toml_get.
  local ct; ct="$(grep -E '"name"[[:space:]]*:' "$OMAC_THEMES/$name/vscode.json" 2>/dev/null \
                  | head -1 | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
  [[ -n "$ct" ]] && omac::theme::apply_vscode "$ct"

  # 3b. bat + git-delta (best-effort): both driven by the apps.toml `bat` name.
  omac::theme::apply_bat "$name"
  omac::theme::apply_delta "$name"

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

# --- One-time wiring (install) -----------------------------------------------

# Install one extension via <cli>, retrying transient marketplace/network
# failures (the #1 cause of a spurious "failed:" during `theme install`).
# "Already installed" exits 0, so it counts as success. On the final failed
# attempt the captured output is echoed so the caller can report *why*.
omac::theme::_install_ext() {   # <cli> <id>
  local cli="$1" id="$2" attempt out
  for attempt in 1 2 3; do
    if out="$("$cli" --install-extension "$id" 2>&1)"; then
      return 0
    fi
    (( attempt < 3 )) && sleep 2
  done
  print -r -- "$out"
  return 1
}

# Pre-install the distinct VS Code/Cursor theme extensions across all themes.
omac::theme::install_extensions() {
  setopt local_options null_glob
  local -a ids; local f id err
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
    if ! err="$(omac::theme::_install_ext code "$id")"; then
      omac::warn "failed: $id — ${err##*$'\n'}"
    fi
    command -v cursor >/dev/null 2>&1 && omac::theme::_install_ext cursor "$id" >/dev/null 2>&1
  done
}

# Scaffold the LazyVim starter into <cfg>/nvim so the themed `neovim.lua` we
# symlink below has a real LazyVim base to load. Non-destructive: if any nvim
# config already exists we leave it untouched (bring your own LazyVim layout).
# Follows https://www.lazyvim.org/installation.
omac::theme::bootstrap_lazyvim() {   # <cfg>
  local nvim="$1/nvim"
  [[ -e "$nvim" ]] && return 0
  command -v git >/dev/null 2>&1 || { omac::warn "git missing; skipped LazyVim scaffold"; return 0; }
  omac::info "scaffolding LazyVim starter into $nvim"
  if git clone --depth 1 https://github.com/LazyVim/starter "$nvim" >/dev/null 2>&1; then
    rm -rf "$nvim/.git"
    omac::ok "LazyVim installed — launch nvim, then run :LazyHealth"
  else
    rm -rf "$nvim" 2>/dev/null   # don't leave a half-cloned config behind
    omac::warn "LazyVim scaffold failed (git clone); themed nvim won't load until installed"
  fi
}

# Point the user's real app configs at omac (idempotent managed blocks/symlink).
omac::theme::wire() {
  local cfg; cfg="$(omac::theme::config_dir)"
  omac::ensure_block "$cfg/ghostty/config" "config-file = $cfg/ghostty/omac-theme.conf"
  omac::theme::bootstrap_lazyvim "$cfg"
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
