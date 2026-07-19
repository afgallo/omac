# The launcher engine: guided first-run activation for Raycast. Sourced by
# cmd/launcher/* so all logic lives here. Pure activation layer — `software`
# installs the Raycast cask; `theme` owns colors; launcher deploys nothing on disk.
#
# The one scriptable step is freeing macOS Spotlight's ⌘Space (symbolic hotkey
# 64) so Raycast can claim it. Everything else is guided (GUI-only).

# Spotlight owns ⌘Space via symbolic hotkey 64. Set once, idempotent across
# re-sourcing (no `readonly`, which would error on a second source).
: ${OMAC_SPOTLIGHT_HOTKEY_ID:=64}

# The command palette: a TypeScript Raycast extension shipped in the repo and
# imported in development mode (not from the Store). Overridable for tests.
: ${OMAC_PALETTE_SRC:="$OMAC_HOME/raycast/omac"}

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

# ── command palette ──────────────────────────────────────────────────────────
# The palette is driven entirely by `omac commands --json`, so it never drifts
# from the CLI. It is imported into Raycast in development mode; there is no
# on-disk marker for "imported into Raycast", so we report the two facts we can
# see (source present, dependencies built) and hand off the one-time import.

# True iff the extension source is present in this checkout.
omac::launcher::palette_present() {
  [[ -f "$OMAC_PALETTE_SRC/package.json" ]]
}

# True iff its npm dependencies are installed (node_modules populated).
omac::launcher::palette_deps_installed() {
  [[ -d "$OMAC_PALETTE_SRC/node_modules/@raycast" ]]
}

# Build the palette and hand off its one-time dev import. Non-fatal throughout:
# a missing checkout or toolchain just prints guidance and returns 0, so it never
# aborts a launcher install over the optional palette. The import itself must run
# interactively (Raycast forbids scripting it), so we install deps and then walk
# the user through `npm run dev`, matching the rest of launcher's guided style.
omac::launcher::palette_install() {
  if ! omac::launcher::palette_present; then
    omac::warn "command palette source not found at $OMAC_PALETTE_SRC — skipping"
    return 0
  fi
  if ! command -v npm >/dev/null 2>&1; then
    omac::warn "npm not found — install Node first (omac software install), then re-run"
    return 0
  fi
  if ! omac::launcher::palette_deps_installed; then
    omac::info "installing command palette dependencies"
    if ! ( cd "$OMAC_PALETTE_SRC" && npm install ); then
      omac::warn "npm install failed — see the output above"
      return 0
    fi
  fi
  omac::info "command palette ready — finish the one-time import:"
  omac::log "1. cd $OMAC_PALETTE_SRC && npm run dev"
  omac::log "2. leave it running until 'omac' appears in Raycast, then press ⌃C."
  omac::log "3. trigger it any time by typing 'omac' in Raycast."
  omac::ok "command palette installed"
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

# Non-mutating status: is Raycast installed / running, ⌘Space freed, and is the
# command palette present and built?
omac::launcher::status() {
  local inst run freed psrc pdeps
  omac::launcher::raycast_present && inst=yes || inst=no
  pgrep -x Raycast >/dev/null 2>&1 && run=yes || run=no
  omac::launcher::spotlight_hotkey_enabled && freed=no || freed=yes
  omac::launcher::palette_present && psrc=yes || psrc=no
  omac::launcher::palette_deps_installed && pdeps=yes || pdeps=no
  printf "%-20s %s\n" "Raycast installed:" "$inst"
  printf "%-20s %s\n" "Raycast running:"   "$run"
  printf "%-20s %s\n" "⌘Space freed:"      "$freed"
  printf "%-20s %s\n" "palette source:"    "$psrc"
  printf "%-20s %s\n" "palette built:"     "$pdeps"
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
  omac::launcher::palette_install
  omac::ok "launcher installed"
}
