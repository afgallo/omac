#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

_launcher_stub_setup
source "$ROOT/lib/launcher.zsh"

# From the default (enabled) state, free_spotlight_hotkey writes disable + applies.
export DEFAULTS_READ_OUT=""
omac::launcher::free_spotlight_hotkey >/dev/null 2>&1
check "free exits 0" "0" "$?"
contains "free wrote symbolichotkeys" "write com.apple.symbolichotkeys" "$(<"$DEFAULTS_LOG")"
contains "free targeted hotkey 64"    "64"          "$(<"$DEFAULTS_LOG")"
contains "free set enabled = 0"       "enabled = 0" "$(<"$DEFAULTS_LOG")"
contains "free applied live"          "-u"          "$(<"$ACTIVATE_LOG")"

# Idempotency: when already disabled, free writes nothing.
: > "$DEFAULTS_LOG"
export DEFAULTS_READ_OUT="AppleSymbolicHotKeys = { 64 = { enabled = 0; }; };"
omac::launcher::free_spotlight_hotkey >/dev/null 2>&1
wrote="$([[ "$(<"$DEFAULTS_LOG")" == *write* ]] && print yes || print no)"
check "free is a no-op when already freed" "no" "$wrote"

# restore re-enables from the disabled state.
: > "$DEFAULTS_LOG"
omac::launcher::restore_spotlight_hotkey >/dev/null 2>&1
contains "restore set enabled = 1" "enabled = 1" "$(<"$DEFAULTS_LOG")"

# apply_hotkey_settings degrades gracefully when activateSettings is absent.
: > "$ACTIVATE_LOG"
export OMAC_ACTIVATE_SETTINGS="/nonexistent/activateSettings"
out="$(omac::launcher::apply_hotkey_settings 2>&1)"
check "apply exits 0 without the binary" "0" "$?"
contains "apply prints re-login hint" "log out" "$out"
finish
