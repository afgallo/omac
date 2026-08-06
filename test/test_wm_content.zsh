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

# Resize covers both axes in both directions — Omarchy's SUPER+-/= (width) and
# SUPER+SHIFT+-/= (height, remapped to cmd-alt so cmd-plus zoom stays native).
_bound() {   # _bound <key> -> the command it maps to, or empty
  grep -E "^$1[[:space:]]*=" "$toml" | head -1 | sed -E "s/^[^=]*=[[:space:]]*'(.*)'.*/\1/"
}
check "cmd-minus narrows"     "resize width -50"  "$(_bound cmd-minus)"
check "cmd-equal widens"      "resize width +50"  "$(_bound cmd-equal)"
check "cmd-alt-minus shortens" "resize height -50" "$(_bound cmd-alt-minus)"
check "cmd-alt-equal heightens" "resize height +50" "$(_bound cmd-alt-equal)"

# Split-orientation toggle (Omarchy SUPER+J togglesplit), distinct from the
# tiles/accordion toggle it sits beside.
check "cmd-alt-slash toggles orientation" "layout horizontal vertical" "$(_bound cmd-alt-slash)"
check "cmd-slash still toggles tiles/accordion" "layout tiles accordion" "$(_bound cmd-slash)"

# Lock (Omarchy SUPER+ESCAPE). Double-quoted like cmd-q — the osascript body has
# single quotes in it — so `_bound` can't parse it; assert on the raw text instead.
contains "cmd-esc locks the screen" \
  "cmd-esc = \"exec-and-forget osascript" "$(<"$toml")"
contains "cmd-esc drives the native Lock Screen shortcut" \
  'keystroke \"q\" using {control down, command down}' "$(<"$toml")"

# The resize sub-mode needs a way back — resize is cumulative and easy to overshoot.
contains "resize mode can balance sizes" "balance-sizes" "$(<"$toml")"

# AeroSpace silently keeps the LAST of a duplicated key, so a dupe is a bind that
# looks present but never fires. Check every binding key across all [mode.*]
# sections is declared once (keys are unique per mode; mode names prefix them).
dupes="$(awk '
  /^\[mode\.[^]]*\.binding\]/ { mode = $0; next }
  /^\[/                       { mode = "";  next }
  mode != "" && /^[a-z0-9-]+[ \t]*=/ { split($0, p, "="); gsub(/[ \t]/, "", p[1]); print mode " " p[1] }
' "$toml" | sort | uniq -d)"
check "no duplicate key bindings" "" "$dupes"
finish
