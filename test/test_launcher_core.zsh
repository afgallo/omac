#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"
export OMAC_ACTIVATE_SETTINGS="/nonexistent/activateSettings"
_launcher_stub_setup

source "$ROOT/lib/launcher.zsh"

# raycast_present: absent then present.
omac::launcher::raycast_present
check "raycast_present false when app missing" "1" "$?"
mkdir -p "$OMAC_RAYCAST_APP"
omac::launcher::raycast_present
check "raycast_present true when app exists" "0" "$?"

# spotlight_hotkey_enabled: empty read → assume enabled (return 0).
export DEFAULTS_READ_OUT=""
omac::launcher::spotlight_hotkey_enabled
check "hotkey assumed enabled when unreadable" "0" "$?"

# spotlight_hotkey_enabled: a dump showing 64 disabled → return 1.
export DEFAULTS_READ_OUT="AppleSymbolicHotKeys = { 64 = { enabled = 0; }; };"
omac::launcher::spotlight_hotkey_enabled
check "hotkey reported disabled from dump" "1" "$?"
finish
