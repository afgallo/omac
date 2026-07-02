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
