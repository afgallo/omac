#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

export OMAC_HOME="$ROOT"
source "$ROOT/lib/paths.zsh"

check "OMAC_WM defaults under OMAC_HOME" "$ROOT/wm" "$OMAC_WM"

for f in aerospace/aerospace.toml borders/bordersrc borders/colors.sh tweaks.conf; do
  present="$([[ -f "$ROOT/wm/$f" ]] && print yes || print no)"
  check "wm/$f exists" "yes" "$present"
done

aero="$(<"$ROOT/wm/aerospace/aerospace.toml")"
contains "aerospace starts at login"     "start-at-login = true"        "$aero"
contains "aerospace binds cmd modifier"  "cmd-1 = 'workspace 1'"        "$aero"
contains "aerospace closes on cmd-q"     "cmd-q = 'close'"              "$aero"
contains "aerospace floats system settings" "com.apple.systempreferences" "$aero"
contains "aerospace float rule runs floating" "run = 'layout floating'" "$aero"
# Default is 6 workspaces: the 6th is bound, the 7th is not.
contains "aerospace binds 6th workspace"  "cmd-6 = 'workspace 6'"        "$aero"
check "aerospace stops at 6 workspaces" "no" "$([[ "$aero" == *"workspace 7"* ]] && print yes || print no)"

brc="$(<"$ROOT/wm/borders/bordersrc")"
contains "bordersrc sources colors" "colors.sh" "$brc"
contains "bordersrc sets active color" "active_color" "$brc"

tweaks="$(<"$ROOT/wm/tweaks.conf")"
contains "tweaks set fast key repeat"    "NSGlobalDomain KeyRepeat int 2" "$tweaks"
contains "tweaks disable window animation" "NSAutomaticWindowAnimationsEnabled bool false" "$tweaks"
finish
