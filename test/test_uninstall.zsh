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

# Isolate HOME too: uninstall un-wires the interactive rc files, whose
# OMAC_ZSHRC/OMAC_BASHRC defaults derive from $HOME. Without this the suite
# stripped the omac block from the REAL ~/.zshrc and ~/.bashrc on every run.
export HOME="$(mktemp -d)"
print -r -- $'# >>> omac >>>\nsource omac.zsh\n# <<< omac <<<' > "$HOME/.zshrc"

# Stub system calls so uninstall's launcher reversal never touches the real Mac.
# Drive a "disabled" hotkey read so restore actually re-enables (and is asserted).
_launcher_stub_setup
export DEFAULTS_READ_OUT="AppleSymbolicHotKeys = { 64 = { enabled = 0; }; };"

zsh "$ROOT/bin/omac" install >/dev/null 2>&1
zsh "$ROOT/bin/omac" uninstall >/dev/null 2>&1
check "uninstall exits 0" "0" "$?"
check "CLI symlink removed" "1" "$(test ! -e "$OMAC_PREFIX/bin/omac" && print 1 || print 0)"
check "zprofile block removed" "0" "$(grep -c '>>> omac >>>' "$OMAC_PROFILE")"
check "zshrc block removed" "0" "$(grep -c '>>> omac >>>' "$HOME/.zshrc")"
check "config removed (OMAC_YES)" "1" "$(test ! -d "$OMAC_CONFIG" && print 1 || print 0)"
contains "uninstall restored ⌘Space" "enabled = 1" "$(<"$DEFAULTS_LOG")"
contains "uninstall applied live"    "-u"          "$(<"$ACTIVATE_LOG")"
finish
