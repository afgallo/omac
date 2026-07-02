#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_STATE="$(mktemp -d)"

out="$(zsh "$ROOT/bin/omac" doctor 2>&1)"
contains "doctor checks Homebrew" "Homebrew" "$out"
contains "doctor checks PATH" "PATH" "$out"
contains "doctor checks zsh version" "zsh" "$out"

# nonzero-exit contract: force a guaranteed failure (prefix bin not on PATH)
OMAC_PREFIX=/definitely/not/on/path zsh "$ROOT/bin/omac" doctor >/dev/null 2>&1
check "doctor exits nonzero when a check fails" "1" "$?"
finish
