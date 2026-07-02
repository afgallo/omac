# The wm engine: deploy AeroSpace + SketchyBar config, apply macOS tweaks, and
# run guided first-run activation. Sourced by cmd/wm/* so all logic lives here.
# Pure config layer — `software` installs the apps; `theme` owns colors.

# The deploy root. One place so tests can redirect via XDG_CONFIG_HOME.
omac::wm::config_dir() {
  print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Deploy the AeroSpace config to the XDG path. AeroSpace errors if both
# ~/.aerospace.toml and the XDG config exist, so back the legacy file aside.
omac::wm::deploy_aerospace() {
  local dest; dest="$(omac::wm::config_dir)/aerospace/aerospace.toml"
  local legacy="$HOME/.aerospace.toml"
  if [[ -e "$legacy" ]]; then
    omac::warn "found $legacy — AeroSpace errors if two configs exist"
    omac::backup_path "$legacy"
  fi
  omac::install_file "$OMAC_WM/aerospace/aerospace.toml" "$dest"
}

# Deploy the whole SketchyBar tree, preserving relative paths, and make the
# entry point and plugins executable.
omac::wm::deploy_sketchybar() {
  setopt local_options extended_glob null_glob
  local src="$OMAC_WM/sketchybar" dest; dest="$(omac::wm::config_dir)/sketchybar"
  local f rel
  for f in "$src"/**/*(.); do
    rel="${f#$src/}"
    omac::install_file "$f" "$dest/$rel"
  done
  chmod +x "$dest/sketchybarrc" "$dest"/plugins/*(.N) 2>/dev/null
  return 0
}

# Apply every tweaks.conf entry via `defaults write`, then remap caps->escape.
# Manifest lines are `domain key type value` (single-token value); blank and
# `#` lines are ignored.
omac::wm::apply_tweaks() {
  omac::require_cmd defaults || return 1
  local manifest="$OMAC_WM/tweaks.conf"
  if [[ ! -f "$manifest" ]]; then
    omac::warn "no tweaks.conf; skipping defaults"
  else
    local line; local -a f
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"          # drop trailing comment
      f=(${=line})                # word-split
      (( ${#f} >= 4 )) || continue
      omac::log "defaults: ${f[1]} ${f[2]}"
      defaults write "${f[1]}" "${f[2]}" "-${f[3]}" "${f[4]}"
    done < "$manifest"
  fi
  omac::wm::remap_caps_escape
  omac::ok "tweaks applied"
}

# Map Caps Lock -> Escape (the user's Omarchy `caps:escape`). Session-scoped;
# reboot persistence via a LaunchAgent is a v1.1 follow-up.
omac::wm::remap_caps_escape() {
  command -v hidutil >/dev/null 2>&1 || return 0
  omac::info "remapping Caps Lock -> Escape"
  hidutil property --set \
    '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}' \
    >/dev/null
}

# Reload both tools' configs (used by `omac wm reload` and after activation).
omac::wm::reload() {
  omac::require_cmd aerospace || return 1
  omac::require_cmd sketchybar || return 1
  aerospace reload-config
  sketchybar --reload
}

# Guided first-run activation: start the SketchyBar service, reload both, and
# open the Accessibility pane (the one grant macOS forbids scripting).
omac::wm::activate() {
  omac::require_cmd brew || return 1
  omac::info "starting sketchybar service"
  brew services start sketchybar
  # AeroSpace start-at-login is set in aerospace.toml; reload if it is running.
  command -v aerospace   >/dev/null 2>&1 && aerospace reload-config 2>/dev/null
  command -v sketchybar  >/dev/null 2>&1 && sketchybar --reload 2>/dev/null
  omac::info "opening Accessibility settings — grant AeroSpace access there"
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  omac::ok "wm activated (grant AeroSpace Accessibility to finish first run)"
}

# Non-mutating status for `omac wm status`: is each component deployed (config
# present) and installed (binary on PATH)?
omac::wm::status() {
  local cfg; cfg="$(omac::wm::config_dir)"
  local name file dep inst
  printf "%-12s %-9s %s\n" "COMPONENT" "DEPLOYED" "INSTALLED"
  for name in aerospace sketchybar; do
    case "$name" in
      aerospace)  file="$cfg/aerospace/aerospace.toml" ;;
      sketchybar) file="$cfg/sketchybar/sketchybarrc"  ;;
    esac
    [[ -f "$file" ]] && dep=yes || dep=no
    command -v "$name" >/dev/null 2>&1 && inst=yes || inst=no
    printf "%-12s %-9s %s\n" "$name" "$dep" "$inst"
  done
}
