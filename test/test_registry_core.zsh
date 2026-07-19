#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
source "$ROOT/lib/registry.zsh"

# Locate a command in the scanned parallel arrays; prints its 1-based index or "".
reg_index() {   # <cmd>
  local i
  for i in {1..${#OMAC_REG_CMD}}; do
    [[ "${OMAC_REG_CMD[i]}" == "$1" ]] && { print -r -- "$i"; return 0; }
  done
  return 1
}

omac::registry::scan
check "scan finds commands" "1" "$(( ${#OMAC_REG_CMD} > 0 ))"

# Kind inference: a status/list/current verb is read; an unmarked verb is mutate.
i="$(reg_index "theme current")"; check "theme current is read" "read" "${OMAC_REG_KIND[i]}"
i="$(reg_index "services up")";   check "services up is mutate"  "mutate" "${OMAC_REG_KIND[i]}"
i="$(reg_index "doctor")";        check "doctor is read"        "read" "${OMAC_REG_KIND[i]}"

# Explicit tags win over inference.
i="$(reg_index "theme reload")";  check "theme reload is apply" "apply" "${OMAC_REG_KIND[i]}"
i="$(reg_index "theme set")"
check "theme set is pick"        "pick"            "${OMAC_REG_KIND[i]}"
check "theme set arg name"       "name"            "${OMAC_REG_ARGNAME[i]}"
check "theme set arg source"     "omac theme list" "${OMAC_REG_ARGSRC[i]}"
check "theme set icon"           "paintbrush"      "${OMAC_REG_ICON[i]}"

# Grouping: a nested leaf defaults to its Title-cased module; a `# group:` override wins.
i="$(reg_index "font set")"; check "font set group is Font" "Font" "${OMAC_REG_GROUP[i]}"
i="$(reg_index "wm status")"; check "wm status group overridden" "Window Management" "${OMAC_REG_GROUP[i]}"
i="$(reg_index "doctor")";   check "flat solo group is General" "General" "${OMAC_REG_GROUP[i]}"

# Hidden commands and parent dispatch stubs never surface as leaves.
reg_index "services boot" >/dev/null; check "services boot hidden"  "1" "$?"
reg_index "commands"      >/dev/null; check "commands hidden"       "1" "$?"
reg_index "theme"         >/dev/null; check "theme parent skipped"  "1" "$?"

# Human help carries the usage line and a group header.
help="$(omac::registry::help)"
contains "help has usage line"  "Usage: omac" "$help"
contains "help has a group header" "Theme:"   "$help"

# JSON: one object per scanned leaf, correctly shaped.
json="$(omac::registry::json)"
contains "json has theme set object" '"cmd":"theme set"' "$json"
contains "json marks the pick kind"  '"kind":"pick"'     "$json"
finish
