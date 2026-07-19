#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)"

# `omac commands` prints the grouped human listing.
human="$(zsh "$ROOT/bin/omac" commands)"
contains "commands prints usage line" "Usage: omac" "$human"
contains "commands groups by section" "Theme:"       "$human"

# `omac commands --json` prints a machine-readable feed the palette can consume.
json="$(zsh "$ROOT/bin/omac" commands --json)"
contains "json feed opens an array"   "["                     "$json"
contains "json feed lists theme set"  '"cmd":"theme set"'     "$json"

# The feed must be valid JSON (parse it if python is available; skip otherwise).
if command -v python3 >/dev/null 2>&1; then
  count="$(print -r -- "$json" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null)"
  check "json feed parses" "0" "$?"
  check "json feed non-empty" "1" "$(( count > 0 ))"
fi
finish
