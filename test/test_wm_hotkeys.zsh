#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/wm_stubs.zsh"
source "$ROOT/lib/common.zsh"
source "$ROOT/lib/paths.zsh"

_wm_stub_setup
source "$ROOT/lib/wm.zsh"

# Disabling frees macOS's ⇧⌘3/4/5 screenshot hotkeys (28/30/184) so they stop
# clobbering AeroSpace's cmd-shift-3/4/5 → move-node-to-workspace.
omac::wm::disable_screenshot_hotkeys >/dev/null 2>&1
check "disable exits 0" "0" "$?"

dlog="$(<"$DEFAULTS_LOG")"
contains "wrote symbolichotkeys"   "write com.apple.symbolichotkeys" "$dlog"
contains "targeted ⇧⌘3 (id 28)"    "-dict-add 28"  "$dlog"
contains "targeted ⇧⌘4 (id 30)"    "-dict-add 30"  "$dlog"
contains "targeted ⇧⌘5 (id 184)"   "-dict-add 184" "$dlog"
contains "flipped enabled = 0"     "enabled = 0"   "$dlog"
# cmd-shift-1/2/6 have no macOS screenshot default — we must not touch other ids.
check "left ⌘Space (id 64) alone"  "no" "$([[ "$dlog" == *"-dict-add 64"* ]] && print yes || print no)"
contains "applied live"            "-u" "$(<"$ACTIVATE_LOG")"

# Idempotent: a second run re-asserts the same dict (still exits 0, still writes).
: > "$DEFAULTS_LOG"
omac::wm::disable_screenshot_hotkeys >/dev/null 2>&1
check "re-run exits 0" "0" "$?"
contains "re-run re-asserts" "-dict-add 28" "$(<"$DEFAULTS_LOG")"

# Missing activateSettings binary is non-fatal (falls back to a re-login hint).
: > "$DEFAULTS_LOG"
export OMAC_ACTIVATE_SETTINGS="/nonexistent/activateSettings"
omac::wm::disable_screenshot_hotkeys >/dev/null 2>&1
check "no activateSettings still exits 0" "0" "$?"

finish
