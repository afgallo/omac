#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

# Fixture wm source tree (isolated from the repo's real wm/).
export OMAC_WM="$(mktemp -d)/wm"
mkdir -p "$OMAC_WM/aerospace" "$OMAC_WM/sketchybar/plugins"
print -r -- "start-at-login = true"          > "$OMAC_WM/aerospace/aerospace.toml"
print -r -- "source colors.sh"               > "$OMAC_WM/sketchybar/sketchybarrc"
print -r -- "export BAR_COLOR=0x0"           > "$OMAC_WM/sketchybar/colors.sh"
print -r -- "echo plugin"                     > "$OMAC_WM/sketchybar/plugins/clock.sh"

# Redirect the deploy root; also isolate HOME for the ~/.aerospace.toml check.
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"

source "$ROOT/lib/wm.zsh"

check "config_dir honors XDG" "$XDG_CONFIG_HOME" "$(omac::wm::config_dir)"

omac::wm::deploy_aerospace >/dev/null 2>&1
present="$([[ -f "$XDG_CONFIG_HOME/aerospace/aerospace.toml" ]] && print yes || print no)"
check "aerospace.toml deployed" "yes" "$present"

# A pre-existing ~/.aerospace.toml must be backed up, not left to collide.
print -r -- "old" > "$HOME/.aerospace.toml"
omac::wm::deploy_aerospace >/dev/null 2>&1
setopt local_options null_glob
backups=("$HOME"/.aerospace.toml.omac-backup.*)
check "legacy ~/.aerospace.toml backed up" "1" "$(( ${#backups} >= 1 ))"

omac::wm::deploy_sketchybar >/dev/null 2>&1
present="$([[ -f "$XDG_CONFIG_HOME/sketchybar/sketchybarrc" ]] && print yes || print no)"
check "sketchybarrc deployed" "yes" "$present"
present="$([[ -f "$XDG_CONFIG_HOME/sketchybar/plugins/clock.sh" ]] && print yes || print no)"
check "sketchybar plugin deployed (tree preserved)" "yes" "$present"
present="$([[ -x "$XDG_CONFIG_HOME/sketchybar/sketchybarrc" ]] && print yes || print no)"
check "sketchybarrc is executable" "yes" "$present"
finish
