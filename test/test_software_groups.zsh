#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

# Fixture manifests dir (isolated from the repo's real software/).
export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
print -r -- 'cask "zed"'     > "$OMAC_SOFTWARE/groups/ides.Brewfile"

source "$ROOT/lib/software.zsh"

groups_out="$(omac::software::groups)"
contains "groups lists shell"     "shell"    "$groups_out"
contains "groups lists ides"      "ides"     "$groups_out"
contains "groups lists runtimes"  "runtimes" "$groups_out"

check "group_file builds path" "$OMAC_SOFTWARE/groups/shell.Brewfile" "$(omac::software::group_file shell)"

omac::software::is_group shell   ; check "is_group shell true"    "0" "$?"
omac::software::is_group runtimes; check "is_group runtimes true" "0" "$?"
omac::software::is_group nope    ; check "is_group nope false"    "1" "$?"
finish
