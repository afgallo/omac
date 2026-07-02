#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

export OMAC_HOME="$ROOT"
source "$ROOT/lib/paths.zsh"

check "OMAC_SOFTWARE defaults under OMAC_HOME" "$ROOT/software" "$OMAC_SOFTWARE"

for grp in shell tuis ides ai guis fonts; do
  present="$([[ -f "$ROOT/software/groups/$grp.Brewfile" ]] && print yes || print no)"
  check "$grp.Brewfile exists" "yes" "$present"
done

present="$([[ -f "$ROOT/software/runtimes.manifest" ]] && print yes || print no)"
check "runtimes.manifest exists" "yes" "$present"

contains "tuis has pgcli"       "pgcli"        "$(<"$ROOT/software/groups/tuis.Brewfile")"
contains "ai has claude-code"   "claude-code"  "$(<"$ROOT/software/groups/ai.Brewfile")"
contains "ai has opencode"      "opencode"     "$(<"$ROOT/software/groups/ai.Brewfile")"
contains "guis has ghostty"     "ghostty"      "$(<"$ROOT/software/groups/guis.Brewfile")"
contains "guis has lastpass"    "lastpass"     "$(<"$ROOT/software/groups/guis.Brewfile")"
contains "guis has aerospace"   "nikitabobko/tap/aerospace" "$(<"$ROOT/software/groups/guis.Brewfile")"
contains "guis has sketchybar"  "FelixKratz/formulae/sketchybar" "$(<"$ROOT/software/groups/guis.Brewfile")"
contains "runtimes node lts"    "node@lts"     "$(<"$ROOT/software/runtimes.manifest")"
finish
