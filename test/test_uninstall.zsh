#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)/omac"
export OMAC_STATE="$(mktemp -d)/omac"
export OMAC_PREFIX="$(mktemp -d)"
export OMAC_PROFILE="$(mktemp -d)/.zprofile"
export OMAC_YES=1   # auto-confirm the config/state deletion

# Stub system calls so uninstall's launcher reversal never touches the real Mac.
# Drive a "disabled" hotkey read so restore actually re-enables (and is asserted).
_launcher_stub_setup
export DEFAULTS_READ_OUT="AppleSymbolicHotKeys = { 64 = { enabled = 0; }; };"

zsh "$ROOT/bin/omac" install >/dev/null 2>&1
zsh "$ROOT/bin/omac" uninstall >/dev/null 2>&1
check "uninstall exits 0" "0" "$?"
check "CLI symlink removed" "1" "$(test ! -e "$OMAC_PREFIX/bin/omac" && print 1 || print 0)"
check "zprofile block removed" "0" "$(grep -c '>>> omac >>>' "$OMAC_PROFILE")"
check "config removed (OMAC_YES)" "1" "$(test ! -d "$OMAC_CONFIG" && print 1 || print 0)"
contains "uninstall restored ⌘Space" "enabled = 1" "$(<"$DEFAULTS_LOG")"
contains "uninstall applied live"    "-u"          "$(<"$ACTIVATE_LOG")"
finish
