#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
mkdir -p "$XDG_CONFIG_HOME/aerospace"
print -r -- "start-at-login = true" > "$XDG_CONFIG_HOME/aerospace/aerospace.toml"

source "$ROOT/lib/wm.zsh"

out="$(omac::wm::status)"
contains "status lists aerospace"        "aerospace"  "$out"
contains "status lists sketchybar"       "sketchybar" "$out"
contains "status shows aerospace deployed" "yes"      "$out"
finish
