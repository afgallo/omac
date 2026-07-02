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
