#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)"

# Assert against the version file (source of truth) so a version bump can't rot
# this test — cmd/version.zsh reads the same file.
ver="$(<"$ROOT/version")"
contains "version prints version string" "$ver" "$(zsh "$ROOT/bin/omac" version)"
path_out="$(zsh "$ROOT/bin/omac" path)"
contains "path prints OMAC_HOME" "OMAC_HOME=$ROOT" "$path_out"
contains "path prints config dir" "OMAC_CONFIG=" "$path_out"
contains "path prints themes dir" "themes=" "$path_out"
contains "path prints current symlink" "current=" "$path_out"
finish
