# The wm engine: deploy AeroSpace + JankyBorders config, apply macOS tweaks, and
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

# Deploy the JankyBorders tree, preserving relative paths, and make the entry
# point (bordersrc) executable.
omac::wm::deploy_borders() {
  setopt local_options extended_glob null_glob
  local src="$OMAC_WM/borders" dest; dest="$(omac::wm::config_dir)/borders"
  local f rel
  for f in "$src"/**/*(.); do
    rel="${f#$src/}"
    omac::install_file "$f" "$dest/$rel" || return  # decline aborts the deploy
  done
  chmod +x "$dest/bordersrc" 2>/dev/null
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
  omac::wm::disable_screenshot_hotkeys
  omac::ok "tweaks applied"
}

# Free macOS's ⇧⌘3/4/5 screenshot shortcuts (symbolic hotkeys 28/30/184) so they
# stop clobbering AeroSpace's cmd-shift-3/4/5 → move-node-to-workspace binds.
# Screenshots stay on Flameshot's own cmd-shift-enter global hotkey (set in
# Flameshot) and the Screenshot app.
#
# Two layers, because macOS 26 (Tahoe) stopped reading com.apple.symbolichotkeys
# at login (verified: enabled=0 on disk survived a reboot while WindowServer kept
# the hotkeys registered):
#  1. prefs write — honored on macOS 14/15 and keeps System Settings consistent;
#     a harmless no-op on Tahoe. Each value dict reproduces the default binding
#     (parameters = ascii, keycode, modifiers; ⇧⌘ = 1179648) and only flips
#     enabled=0, so it's a clean, reversible override.
#  2. SkyLight helper — flips WindowServer's live hotkey table directly (needed
#     on Tahoe, works everywhere). Session-scoped, so a LaunchAgent re-applies
#     it at every login — same pattern as the Caps->Escape remap.
omac::wm::disable_screenshot_hotkeys() {
  omac::require_cmd defaults || return 1
  local entry id params
  for entry in '28:51, 20, 1179648' '30:52, 21, 1179648' '184:53, 23, 1179648'; do
    id="${entry%%:*}"; params="${entry#*:}"
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
      "$id" "{ enabled = 0; value = { parameters = ( $params ); type = standard; }; }"
  done
  omac::wm::build_hotkeys_helper || return 0  # no compiler: warned, prefs still set
  "$OMAC_HOTKEYS_BIN" 28 0 30 0 184 0 >/dev/null \
    || omac::warn "could not update live hotkey table (will apply at next login)"
  omac::wm::install_hotkeys_agent
  omac::info "disabled ⇧⌘3/4/5 screenshots (freed for AeroSpace move-to-workspace)"
}

# Compile the SkyLight helper into OMAC_STATE, skipping when the binary is
# already newer than its source. swiftc ships with the Xcode CLT, which brew (an
# omac prerequisite) already requires; a missing compiler is a warn, not a
# failure — the prefs layer still covers pre-Tahoe systems.
omac::wm::build_hotkeys_helper() {
  if [[ -x "$OMAC_HOTKEYS_BIN" && "$OMAC_HOTKEYS_BIN" -nt "$OMAC_HOTKEYS_SRC" ]]; then
    return 0
  fi
  if ! command -v "$OMAC_SWIFTC" >/dev/null 2>&1; then
    omac::warn "swiftc not found — screenshot shortcuts stay active on macOS 26+"
    return 1
  fi
  mkdir -p "${OMAC_HOTKEYS_BIN:h}"
  omac::log "compiling hotkeys helper"
  "$OMAC_SWIFTC" -O "$OMAC_HOTKEYS_SRC" -o "$OMAC_HOTKEYS_BIN" || {
    omac::warn "hotkeys helper failed to compile"
    return 1
  }
}

# LaunchAgent that re-applies the WindowServer hotkey state at every login (the
# live table resets each session). Idempotent: plist rewritten and agent
# re-bootstrapped on every call. Mirrors install_caps_agent.
omac::wm::install_hotkeys_agent() {
  local label="com.omac.hotkeys"
  local agents="${OMAC_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}"
  local plist="$agents/$label.plist"
  mkdir -p "$agents"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$OMAC_HOTKEYS_BIN</string>
    <string>28</string><string>0</string>
    <string>30</string><string>0</string>
    <string>184</string><string>0</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
  command -v launchctl >/dev/null 2>&1 || return 0
  # Re-bootstrap so an existing agent picks up changes. bootout is a no-op (and
  # errors) when nothing is loaded yet, so swallow its failure.
  local domain="gui/$(id -u)"
  launchctl bootout "$domain/$label" 2>/dev/null
  launchctl bootstrap "$domain" "$plist" 2>/dev/null
  omac::info "installed hotkeys LaunchAgent ($plist)"
}

# Map Caps Lock -> Escape (the user's Omarchy `caps:escape`). `hidutil` only
# applies to the current login session, so we also install a LaunchAgent that
# re-applies the mapping at every login — otherwise the remap vanishes on reboot.
omac::wm::caps_mapping() {
  print -r -- '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}'
}

omac::wm::remap_caps_escape() {
  command -v hidutil >/dev/null 2>&1 || return 0
  omac::info "remapping Caps Lock -> Escape"
  hidutil property --set "$(omac::wm::caps_mapping)" >/dev/null
  omac::wm::install_caps_agent
}

# Write and load a per-user LaunchAgent that re-runs the hidutil remap at login,
# so Caps Lock -> Escape survives reboots. Idempotent: the plist is rewritten
# and the agent is re-bootstrapped on every call.
omac::wm::install_caps_agent() {
  local label="com.omac.capsescape"
  local agents="${OMAC_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}"
  local plist="$agents/$label.plist"
  mkdir -p "$agents"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/hidutil</string>
    <string>property</string>
    <string>--set</string>
    <string>$(omac::wm::caps_mapping)</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
  command -v launchctl >/dev/null 2>&1 || return 0
  # Re-bootstrap so an existing agent picks up changes. bootout is a no-op (and
  # errors) when nothing is loaded yet, so swallow its failure.
  local domain="gui/$(id -u)"
  launchctl bootout "$domain/$label" 2>/dev/null
  launchctl bootstrap "$domain" "$plist" 2>/dev/null
  omac::info "installed Caps->Escape LaunchAgent ($plist)"
}

# Reload both tools' configs (used by `omac wm reload` and after activation).
# Re-running the deployed bordersrc pushes fresh options to the live borders
# daemon (non-blocking when it is already running).
omac::wm::reload() {
  omac::require_cmd aerospace || return 1
  omac::require_cmd borders || return 1
  aerospace reload-config || return   # AeroSpace failure is authoritative
  # Refreshing the borders daemon is best-effort — a failed push must not fail
  # the whole reload.
  local rc; rc="$(omac::wm::config_dir)/borders/bordersrc"
  [[ -x "$rc" ]] && "$rc" >/dev/null 2>&1
  return 0
}

# Guided first-run activation: start the borders service, reload both, and open
# the Accessibility pane (the one grant macOS forbids scripting).
omac::wm::activate() {
  omac::require_cmd brew || return 1
  omac::info "starting borders service"
  brew services start borders
  # AeroSpace start-at-login is set in aerospace.toml; reload if it is running.
  # Capture output so a config error surfaces as one clean line instead of a raw
  # dump — and so we don't imply success when the reload actually failed.
  local out
  if command -v aerospace >/dev/null 2>&1; then
    out="$(aerospace reload-config 2>&1)" || omac::warn "AeroSpace config not reloaded: ${out##*$'\n'}"
  fi
  local rc; rc="$(omac::wm::config_dir)/borders/bordersrc"
  command -v borders >/dev/null 2>&1 && [[ -x "$rc" ]] && "$rc" >/dev/null 2>&1
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
  for name in aerospace borders; do
    case "$name" in
      aerospace) file="$cfg/aerospace/aerospace.toml" ;;
      borders)   file="$cfg/borders/bordersrc"        ;;
    esac
    [[ -f "$file" ]] && dep=yes || dep=no
    command -v "$name" >/dev/null 2>&1 && inst=yes || inst=no
    printf "%-12s %-9s %s\n" "$name" "$dep" "$inst"
  done
}

# Orchestrate the guided first-run: guard the apps are installed, deploy both
# configs, apply tweaks, then activate.
omac::wm::install() {
  if ! command -v aerospace >/dev/null 2>&1 || ! command -v borders >/dev/null 2>&1; then
    omac::error "AeroSpace and JankyBorders must be installed first"
    omac::info "run: omac software install"
    return 1
  fi
  # A declined overwrite aborts here — don't apply tweaks or activate a
  # half-deployed config.
  omac::wm::deploy_aerospace || return
  omac::wm::deploy_borders   || return
  omac::wm::apply_tweaks
  omac::wm::activate
  omac::ok "wm installed"
}
