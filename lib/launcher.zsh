# The launcher engine: guided first-run activation for Raycast. Sourced by
# cmd/launcher/* so all logic lives here. Pure activation layer — `software`
# installs the Raycast cask; `theme` owns colors; launcher deploys nothing on disk.
#
# The one scriptable step is freeing macOS Spotlight's ⌘Space (symbolic hotkey
# 64) so Raycast can claim it. Everything else is guided (GUI-only).

# Spotlight owns ⌘Space via symbolic hotkey 64. Set once, idempotent across
# re-sourcing (no `readonly`, which would error on a second source).
: ${OMAC_SPOTLIGHT_HOTKEY_ID:=64}

# True iff Raycast is installed. Raycast ships no PATH binary, so detect the app
# bundle. OMAC_RAYCAST_APP is a test seam (see lib/paths.zsh).
omac::launcher::raycast_present() {
  [[ -d "$OMAC_RAYCAST_APP" ]]
}

# Best-effort: is Spotlight's ⌘Space still enabled? Unreadable/absent → assume
# enabled (the macOS default). Used by status and for idempotency.
omac::launcher::spotlight_hotkey_enabled() {
  local dump
  dump="$(defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys 2>/dev/null)" || return 0
  # If the id-64 dict carries "enabled = 0", the shortcut is disabled; otherwise
  # (including not found) treat it as enabled. Best-effort string match.
  [[ "$dump" != *"$OMAC_SPOTLIGHT_HOTKEY_ID = "*"enabled = 0"* ]]
}

# Apply symbolic-hotkey changes live. OMAC_ACTIVATE_SETTINGS is the private
# binary (test seam); if it is missing, fall back to a re-login hint (non-fatal).
omac::launcher::apply_hotkey_settings() {
  if [[ -x "$OMAC_ACTIVATE_SETTINGS" ]]; then
    "$OMAC_ACTIVATE_SETTINGS" -u
  else
    omac::warn "log out and back in for the ⌘Space change to take effect"
  fi
}

# Disable Spotlight's ⌘Space so Raycast can bind it. Idempotent — a no-op if
# already freed. The dict preserves the binding definition and only flips enabled.
omac::launcher::free_spotlight_hotkey() {
  omac::require_cmd defaults || return 1
  if ! omac::launcher::spotlight_hotkey_enabled; then
    omac::ok "Spotlight ⌘Space already freed"
    return 0
  fi
  omac::info "freeing ⌘Space from Spotlight"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
    "$OMAC_SPOTLIGHT_HOTKEY_ID" \
    '{ enabled = 0; value = { parameters = ( 65535, 49, 1048576 ); type = standard; }; }'
  omac::launcher::apply_hotkey_settings
}

# Re-enable Spotlight's ⌘Space — the clean inverse used by uninstall. No-op if
# already enabled (so a plain uninstall that never freed it does nothing).
omac::launcher::restore_spotlight_hotkey() {
  omac::require_cmd defaults || return 1
  if omac::launcher::spotlight_hotkey_enabled; then
    return 0
  fi
  omac::info "restoring Spotlight ⌘Space"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
    "$OMAC_SPOTLIGHT_HOTKEY_ID" \
    '{ enabled = 1; value = { parameters = ( 65535, 49, 1048576 ); type = standard; }; }'
  omac::launcher::apply_hotkey_settings
}

# Guided activation: open Raycast and the settings panes, then print the manual
# steps macOS/Raycast forbid scripting.
omac::launcher::activate() {
  omac::info "opening Raycast"
  open -a Raycast
  omac::info "opening the settings panes to finish setup"
  open "x-apple.systempreferences:com.apple.preference.keyboard"
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  omac::info "manual steps (GUI-only):"
  omac::log "1. In Raycast, set the launcher hotkey to ⌘Space."
  omac::log "2. In Raycast, enable Clipboard History (and give it a hotkey)."
  omac::log "3. Grant Raycast Accessibility in System Settings > Privacy."
  omac::ok "launcher activated (finish the 3 manual steps above)"
}

# Non-mutating status: is Raycast installed / running, and is ⌘Space freed?
omac::launcher::status() {
  local inst run freed
  omac::launcher::raycast_present && inst=yes || inst=no
  pgrep -x Raycast >/dev/null 2>&1 && run=yes || run=no
  omac::launcher::spotlight_hotkey_enabled && freed=no || freed=yes
  printf "%-20s %s\n" "Raycast installed:" "$inst"
  printf "%-20s %s\n" "Raycast running:"   "$run"
  printf "%-20s %s\n" "⌘Space freed:"      "$freed"
}

# Orchestrate the guided first-run: guard Raycast installed, free ⌘Space, then
# run guided activation.
omac::launcher::install() {
  if ! omac::launcher::raycast_present; then
    omac::error "Raycast must be installed first"
    omac::info "run: omac software install"
    return 1
  fi
  omac::launcher::free_spotlight_hotkey
  omac::launcher::activate
  omac::ok "launcher installed"
}
