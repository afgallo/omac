#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/wm_stubs.zsh"
source "$ROOT/lib/common.zsh"

# Fixture source tree.
export OMAC_WM="$(mktemp -d)/wm"
mkdir -p "$OMAC_WM/aerospace" "$OMAC_WM/sketchybar/plugins"
print -r -- "start-at-login = true" > "$OMAC_WM/aerospace/aerospace.toml"
print -r -- "source colors.sh"      > "$OMAC_WM/sketchybar/sketchybarrc"
print -r -- "export BAR_COLOR=0x0"  > "$OMAC_WM/sketchybar/colors.sh"
print -r -- "NSGlobalDomain KeyRepeat int 2" > "$OMAC_WM/tweaks.conf"

export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"

# Guard first, BEFORE stubs are on PATH: no aerospace binary -> hard error.
source "$ROOT/lib/wm.zsh"
( PATH="/usr/bin:/bin"; omac::wm::install ) >/dev/null 2>&1
check "install without apps exits 1" "1" "$?"
hint="$( ( PATH="/usr/bin:/bin"; omac::wm::install ) 2>&1 )"
contains "guard hints software install" "software install" "$hint"

# Now with stubbed apps on PATH -> full flow.
_wm_stub_setup
omac::wm::install >/dev/null 2>&1
check "install exits 0" "0" "$?"
present="$([[ -f "$XDG_CONFIG_HOME/aerospace/aerospace.toml" ]] && print yes || print no)"
check "install deployed aerospace" "yes" "$present"
present="$([[ -f "$XDG_CONFIG_HOME/sketchybar/sketchybarrc" ]] && print yes || print no)"
check "install deployed sketchybar" "yes" "$present"
contains "install applied a tweak"   "write NSGlobalDomain KeyRepeat" "$(<"$DEFAULTS_LOG")"
contains "install ran activation"    "Privacy_Accessibility"          "$(<"$OPEN_LOG")"
finish
