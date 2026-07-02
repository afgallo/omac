#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/software_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
# The stub `brew` exits 1 whenever its args contain "broken" — simulates one bad group.
print -r -- 'cask "whatever"' > "$OMAC_SOFTWARE/groups/broken.Brewfile"
print -r -- 'node@lts'         > "$OMAC_SOFTWARE/runtimes.manifest"

_stub_setup
source "$ROOT/lib/software.zsh"

out="$(omac::software::install_all 2>&1)"
rc="$?"
check "install_all reports failure rc" "1" "$rc"
contains "summary names failed group" "broken" "$out"

log="$(<"$BREW_LOG")"
contains "shell group still installed (continued)" "shell.Brewfile" "$log"
contains "broken group was attempted"              "broken.Brewfile" "$log"
contains "runtimes still ran after failure"        "use -g" "$(<"$MISE_LOG")"
finish
