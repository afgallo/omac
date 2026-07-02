#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)"

contains "no args prints usage" "Usage: omac" "$(zsh "$ROOT/bin/omac")"
contains "help lists itself" "help" "$(zsh "$ROOT/bin/omac" help)"
unknown_out="$(zsh "$ROOT/bin/omac" no-such-command 2>&1)"
contains "unknown command warns" "unknown command" "$unknown_out"
zsh "$ROOT/bin/omac" no-such-command >/dev/null 2>&1
check "unknown command exits nonzero" "1" "$?"

# config.zsh is sourced: an override placed there is visible to a command
print -r -- 'export OMAC_PROBE=seen-from-config' > "$OMAC_CONFIG/config.zsh"
print -r -- '# help: probe' > "$ROOT/cmd/_probe.zsh"
print -r -- 'print -r -- "PROBE=$OMAC_PROBE"' >> "$ROOT/cmd/_probe.zsh"
contains "config.zsh is sourced" "PROBE=seen-from-config" "$(zsh "$ROOT/bin/omac" _probe)"
rm -f "$ROOT/cmd/_probe.zsh"
finish
