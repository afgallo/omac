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
