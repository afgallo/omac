#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/wm_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_WM="$(mktemp -d)/wm"; mkdir -p "$OMAC_WM"
_wm_stub_setup
source "$ROOT/lib/wm.zsh"

omac::wm::activate >/dev/null 2>&1
check "activate exits 0" "0" "$?"
contains "activate starts sketchybar service" "services start sketchybar" "$(<"$BREW_LOG")"
contains "activate opens Accessibility pane"  "Privacy_Accessibility"     "$(<"$OPEN_LOG")"

omac::wm::reload >/dev/null 2>&1
check "reload exits 0" "0" "$?"
contains "reload reloads aerospace"  "reload-config" "$(<"$AEROSPACE_LOG")"
contains "reload reloads sketchybar" "--reload"      "$(<"$SKETCHYBAR_LOG")"
finish
