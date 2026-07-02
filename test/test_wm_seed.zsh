#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

export OMAC_HOME="$ROOT"
source "$ROOT/lib/paths.zsh"

check "OMAC_WM defaults under OMAC_HOME" "$ROOT/wm" "$OMAC_WM"

for f in aerospace/aerospace.toml sketchybar/sketchybarrc sketchybar/colors.sh \
         sketchybar/plugins/aerospace.sh sketchybar/plugins/clock.sh tweaks.conf; do
  present="$([[ -f "$ROOT/wm/$f" ]] && print yes || print no)"
  check "wm/$f exists" "yes" "$present"
done

aero="$(<"$ROOT/wm/aerospace/aerospace.toml")"
contains "aerospace starts at login"     "start-at-login = true"        "$aero"
contains "aerospace binds cmd modifier"  "cmd-1 = 'workspace 1'"        "$aero"
contains "aerospace closes on cmd-q"     "cmd-q = 'close'"              "$aero"
contains "aerospace notifies sketchybar" "exec-on-workspace-change"     "$aero"

sbrc="$(<"$ROOT/wm/sketchybar/sketchybarrc")"
contains "sketchybarrc sources colors" "colors.sh" "$sbrc"

tweaks="$(<"$ROOT/wm/tweaks.conf")"
contains "tweaks set fast key repeat" "NSGlobalDomain KeyRepeat int 2" "$tweaks"
finish
