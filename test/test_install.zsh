#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)/omac"
export OMAC_STATE="$(mktemp -d)/omac"
export OMAC_PREFIX="$(mktemp -d)"
export OMAC_PROFILE="$(mktemp -d)/.zprofile"

out="$(zsh "$ROOT/bin/omac" install 2>&1)"
check "install exits 0" "0" "$?"
check "CLI symlinked into prefix/bin" "$ROOT/bin/omac" "$(readlink "$OMAC_PREFIX/bin/omac")"
check "config seeded" "1" "$(test -f "$OMAC_CONFIG/config.zsh" && print 1 || print 0)"
check "zprofile block written" "1" "$(grep -c '>>> omac >>>' "$OMAC_PROFILE")"
contains "zprofile block has shellenv" "brew shellenv" "$(<"$OMAC_PROFILE")"
check "migrations baselined on first install" "1" "$(ls "$OMAC_STATE/migrations" 2>/dev/null | grep -c example)"

# second run is idempotent: still exits 0 and does NOT duplicate the block
zsh "$ROOT/bin/omac" install >/dev/null 2>&1
check "re-run still exits 0" "0" "$?"
check "block not duplicated" "1" "$(grep -c '>>> omac >>>' "$OMAC_PROFILE")"
finish
