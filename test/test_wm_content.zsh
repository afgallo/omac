#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

toml="$ROOT/wm/aerospace/aerospace.toml"
check "aerospace.toml present" "yes" "$([[ -f "$toml" ]] && print yes || print no)"

# Root-level callbacks (e.g. exec-on-workspace-change) must appear BEFORE the
# first [table] header — otherwise TOML nests them (gaps.exec-on-workspace-change)
# and AeroSpace rejects the config as an unknown key.
first_table="$(grep -nE '^\[' "$toml" | head -1 | cut -d: -f1)"
exec_line="$(grep -nE '^exec-on-workspace-change' "$toml" | head -1 | cut -d: -f1)"
check "exec-on-workspace-change is a root key" "yes" \
  "$([[ -n "$exec_line" && -n "$first_table" && "$exec_line" -lt "$first_table" ]] && print yes || print no)"
finish
