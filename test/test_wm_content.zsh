#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

toml="$ROOT/wm/aerospace/aerospace.toml"
check "aerospace.toml present" "yes" "$([[ -f "$toml" ]] && print yes || print no)"

# Float rules are a top-level array-of-tables. Each `[[on-window-detected]]`
# header must sit at column 0 (not indented under another [table]) or TOML would
# nest it and AeroSpace would reject the config. Every rule also needs a `run =`.
rule_headers="$(grep -cE '^\[\[on-window-detected\]\]' "$toml")"
run_lines="$(grep -cE "^run = 'layout floating'" "$toml")"
check "float rules present" "yes" "$([[ "$rule_headers" -ge 1 ]] && print yes || print no)"
check "every float rule is a top-level table with a run" "yes" \
  "$([[ "$rule_headers" -eq "$run_lines" ]] && print yes || print no)"
# No `[[on-window-detected]]` may appear indented (which would nest it).
check "no indented on-window-detected header" "no" \
  "$([[ -n "$(grep -E '^[[:space:]]+\[\[on-window-detected\]\]' "$toml")" ]] && print yes || print no)"
finish
