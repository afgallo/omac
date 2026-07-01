#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

HOME=/tmp/fakehome
unset OMAC_CONFIG OMAC_STATE OMAC_PREFIX OMAC_PROFILE OMAC_CURRENT
source "$ROOT/lib/paths.zsh"
source "$ROOT/lib/common.zsh"

check "config defaults under HOME" "/tmp/fakehome/.config/omac" "$OMAC_CONFIG"
check "state defaults under HOME" "/tmp/fakehome/.local/state/omac" "$OMAC_STATE"
check "profile defaults to .zprofile" "/tmp/fakehome/.zprofile" "$OMAC_PROFILE"
check "current under config dir" "/tmp/fakehome/.config/omac/current" "$OMAC_CURRENT"
check "prefix honors OMAC_PREFIX" "/tmp/pfx" "$(OMAC_PREFIX=/tmp/pfx omac::prefix)"
check "require_cmd fails on missing" "1" "$(omac::require_cmd definitely-not-a-real-cmd >/dev/null 2>&1; print $?)"
# path_contains (run in subshells so the test process's own PATH is untouched)
check "path_contains finds dir" "0" "$(PATH=/a:/opt/homebrew/bin:/b; omac::path_contains /opt/homebrew/bin; print $?)"
check "path_contains rejects missing" "1" "$(PATH=/a:/b; omac::path_contains /opt/homebrew/bin; print $?)"
# safe, non-destructive file deploy (backup-on-overwrite)
tmp="$(mktemp -d)"
print -r -- one > "$tmp/src"
omac::install_file "$tmp/src" "$tmp/dst" >/dev/null 2>&1
check "install_file creates a missing dest" "one" "$(<"$tmp/dst")"
OMAC_YES=1 omac::install_file "$tmp/src" "$tmp/dst" >/dev/null 2>&1
# List-then-grep, not a bare glob: an unmatched glob is a hard error under zsh NOMATCH.
check "install_file leaves an identical dest un-backed-up" "0" "$(ls "$tmp" | grep -c omac-backup)"
print -r -- two > "$tmp/dst"
OMAC_YES=1 omac::install_file "$tmp/src" "$tmp/dst" >/dev/null 2>&1
check "install_file overwrites a differing dest" "one" "$(<"$tmp/dst")"
check "install_file backs up the replaced file" "1" "$(ls "$tmp" | grep -c omac-backup)"
finish
