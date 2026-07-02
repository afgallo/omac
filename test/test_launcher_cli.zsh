#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"

# Minimal fake OMAC_HOME (symlinked lib/bin/cmd) so the dispatcher runs.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export HOME="$(mktemp -d)"
export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"; mkdir -p "$OMAC_RAYCAST_APP"
export DEFAULTS_READ_OUT=""
_launcher_stub_setup

# bare usage
bare="$(zsh "$fake/bin/omac" launcher)"
contains "bare prints usage"     "Usage"   "$bare"
contains "bare mentions install" "install" "$bare"

# unknown subcommand -> nonzero
zsh "$fake/bin/omac" launcher bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

# install
zsh "$fake/bin/omac" launcher install >/dev/null 2>&1
check "cli install exits 0" "0" "$?"
contains "cli install freed ⌘Space" "write com.apple.symbolichotkeys" "$(<"$DEFAULTS_LOG")"

# status
out="$(zsh "$fake/bin/omac" launcher status)"
contains "cli status shows Raycast row" "Raycast installed" "$out"
finish
