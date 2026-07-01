#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)"

contains "version prints version string" "0.1.0" "$(zsh "$ROOT/bin/omac" version)"
path_out="$(zsh "$ROOT/bin/omac" path)"
contains "path prints OMAC_HOME" "OMAC_HOME=$ROOT" "$path_out"
contains "path prints config dir" "OMAC_CONFIG=" "$path_out"
contains "path prints themes dir" "themes=" "$path_out"
contains "path prints current symlink" "current=" "$path_out"
finish
