#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/software_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"

_stub_setup
source "$ROOT/lib/software.zsh"

BREW_CHECK_RC=0 check "satisfied when bundle check passes" "satisfied" "$(BREW_CHECK_RC=0 omac::software::group_status shell)"
check "missing when bundle check fails"   "missing"   "$(BREW_CHECK_RC=1 omac::software::group_status shell)"
check "runtimes satisfied when mise present" "satisfied" "$(omac::software::group_status runtimes)"
finish
