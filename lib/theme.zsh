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
