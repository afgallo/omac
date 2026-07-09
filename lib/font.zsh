# The font engine: switch the mono font across Ghostty — and every terminal TUI
# it hosts (nvim, htop, lazygit, bat…) — plus VS Code/Cursor. Orthogonal to the
# theme seam: the font lives in its own rendered files, so a theme switch never
# changes the typeface and a font switch never touches colors. cmd/font/* stay
# thin; all logic here, namespaced omac::font::*. Depends only on common.zsh.

# Deploy roots. One place each so tests redirect via XDG_CONFIG_HOME / OMAC_APPSUPPORT.
omac::font::config_dir()     { print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}"; }
omac::font::appsupport_dir() { print -r -- "$OMAC_APPSUPPORT"; }

# --- Registry ----------------------------------------------------------------

# Print bundled font slugs, sorted.
omac::font::list_names() {
  setopt local_options null_glob
  local d
  for d in "$OMAC_FONTS"/*(/); do print -r -- "${d:t}"; done | sort
}

omac::font::is_font() { [[ -d "$OMAC_FONTS/$1" ]]; }    # <slug>

# Resolve a selector to an actual font-family string. A registry slug maps to its
# font.toml `family`; anything else is used verbatim (passthrough), so
# `omac font set "Comic Code"` works with no bundled entry.
omac::font::resolve_family() {   # <selector>
  local sel="$1" fam
  if [[ -f "$OMAC_FONTS/$sel/font.toml" ]]; then
    fam="$(omac::toml_get "$OMAC_FONTS/$sel/font.toml" family)" && { print -r -- "$fam"; return 0; }
  fi
  print -r -- "$sel"
}

# Active selection, persisted in config.zsh (falls back to the default font;
# empty size means "leave each app's own default"). Nested defaults keep these
# safe under `setopt no_unset` even if paths.zsh has not been sourced.
omac::font::current()     { print -r -- "${OMAC_ACTIVE_FONT:-${OMAC_DEFAULT_FONT:-jetbrains-mono}}"; }
omac::font::active_size() { print -r -- "${OMAC_ACTIVE_FONT_SIZE:-}"; }

# --- Renderers / appliers ----------------------------------------------------

# Ghostty font fragment: family (+ size when set). Its own file so a theme
# switch, which rewrites omac-theme.conf, leaves the font alone.
omac::font::render_ghostty() {   # <dest-file> <selector> [size]
  local dest="$1" sel="$2" size="${3:-}" fam
  fam="$(omac::font::resolve_family "$sel")"
  mkdir -p "${dest:h}"
  {
    print -r -- "# omac — rendered by 'omac font set'. Do not edit."
    print -r -- "font-family = \"$fam\""
    [[ -n "$size" ]] && print -r -- "font-size = $size"
  } > "$dest"
}

# Keep the ghostty config including BOTH omac fragments (theme colors + font) and
# seed a default font file if none exists, so the include never dangles. One
# managed block owns both `config-file` lines (remove+ensure upgrades older
# single-include installs). Never clobbers an existing font choice.
omac::font::ensure_ghostty_seam() {   # <cfg-dir>
  local cfg="$1"
  local themeconf="$cfg/ghostty/omac-theme.conf" fontconf="$cfg/ghostty/omac-font.conf"
  omac::remove_block "$cfg/ghostty/config"
  omac::ensure_block "$cfg/ghostty/config" \
    "config-file = $themeconf"$'\n'"config-file = $fontconf"
  [[ -f "$fontconf" ]] || \
    omac::font::render_ghostty "$fontconf" "$(omac::font::current)" "$(omac::font::active_size)"
}

# VS Code/Cursor editor + integrated-terminal font (and size when set). Applies
# live — both editors watch settings.json — so no reload signal is needed.
omac::font::_vscode_write() {    # <family> <size> <settings-file>
  local fam="$1" size="$2" f="$3"
  omac::json_set_raw "$f" "editor.fontFamily" "\"$fam\""
  omac::json_set_raw "$f" "terminal.integrated.fontFamily" "\"$fam\""
  [[ -n "$size" ]] && omac::json_set_raw "$f" "editor.fontSize" "$size"
}

omac::font::apply_vscode() {     # <family> <size>
  local fam="$1" size="$2" as; as="$(omac::font::appsupport_dir)"
  omac::font::_vscode_write "$fam" "$size" "$as/Code/User/settings.json"
  [[ -d "$as/Cursor" ]] && omac::font::_vscode_write "$fam" "$size" "$as/Cursor/User/settings.json"
  omac::info "editor font: $fam${size:+ ${size}pt}"
}

# Nudge (don't block) when a bundled font isn't installed yet. No-op for
# passthrough families and when brew is unavailable.
omac::font::warn_if_missing() {  # <selector>
  omac::font::is_font "$1" || return 0
  command -v brew >/dev/null 2>&1 || return 0
  local cask; cask="$(omac::toml_get "$OMAC_FONTS/$1/font.toml" cask)" || return 0
  [[ -n "$cask" ]] || return 0
  brew list --cask "$cask" >/dev/null 2>&1 \
    || omac::warn "$cask not installed — run: omac software install (group: fonts)"
}

# --- Orchestration -----------------------------------------------------------

omac::font::persist() {          # <selector> <size>
  omac::config_set OMAC_ACTIVE_FONT "$1"
  omac::config_set OMAC_ACTIVE_FONT_SIZE "$2"
}

# The switch: resolve, render ghostty + editors, reload live, persist.
omac::font::set() {              # <selector> [size]
  local sel="$1" size="${2:-}"
  if [[ -z "$sel" ]]; then
    omac::error "usage: omac font set <name> [size]"
    omac::font::list_names
    return 1
  fi
  # Size: given one wins, else keep the persisted size. Positive integer only.
  [[ -z "$size" ]] && size="$(omac::font::active_size)"
  if [[ -n "$size" && "$size" != <1-> ]]; then
    omac::error "invalid font size: $size (want a positive integer)"
    return 1
  fi
  local fam; fam="$(omac::font::resolve_family "$sel")"
  omac::font::warn_if_missing "$sel"

  local cfg; cfg="$(omac::font::config_dir)"
  # 1. Ghostty: render the font file, then ensure the config includes it.
  omac::font::render_ghostty "$cfg/ghostty/omac-font.conf" "$sel" "$size"
  omac::font::ensure_ghostty_seam "$cfg"
  # 2. Editors.
  omac::font::apply_vscode "$fam" "$size"
  # 3. Reload live: Ghostty re-reads on SIGUSR2 (its TUIs follow); editors auto.
  omac::signal_app USR2 ghostty
  # 4. Persist.
  omac::font::persist "$sel" "$size"

  omac::ok "font set: $fam${size:+ ${size}pt}"
  omac::info "ghostty + its TUIs reload live; VS Code/Cursor apply on save"
}

# Re-apply the current font (re-render + reload) without changing the selection.
omac::font::reload() {
  omac::font::set "$(omac::font::current)" "$(omac::font::active_size)"
}
