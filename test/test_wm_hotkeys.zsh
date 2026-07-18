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

# Layer 1: prefs (honored pre-Tahoe, keeps System Settings display consistent).
dlog="$(<"$DEFAULTS_LOG")"
contains "wrote symbolichotkeys"   "write com.apple.symbolichotkeys" "$dlog"
contains "targeted ⇧⌘3 (id 28)"    "-dict-add 28"  "$dlog"
contains "targeted ⇧⌘4 (id 30)"    "-dict-add 30"  "$dlog"
contains "targeted ⇧⌘5 (id 184)"   "-dict-add 184" "$dlog"
contains "flipped enabled = 0"     "enabled = 0"   "$dlog"
# cmd-shift-1/2/6 have no macOS screenshot default — we must not touch other ids.
check "left ⌘Space (id 64) alone"  "no" "$([[ "$dlog" == *"-dict-add 64"* ]] && print yes || print no)"

# Layer 2: SkyLight helper — macOS 26+ ignores the plist, so the live
# WindowServer table must be set directly, and re-set at every login.
contains "helper compiled from src" "$OMAC_HOTKEYS_SRC" "$(<"$SWIFTC_LOG")"
contains "helper flipped live table" "28 0 30 0 184 0" "$(<"$HOTKEYS_LOG")"
plist="$OMAC_LAUNCHAGENTS/com.omac.hotkeys.plist"
check "hotkeys LaunchAgent written" "yes" "$([[ -f "$plist" ]] && print yes || print no)"
contains "LaunchAgent runs the helper"  "$OMAC_HOTKEYS_BIN" "$(<"$plist")"
contains "LaunchAgent re-disables ⇧⌘5"  "<string>184</string>" "$(<"$plist")"
contains "LaunchAgent bootstrapped"     "bootstrap" "$(<"$LAUNCHCTL_LOG")"

# Idempotent re-run: fresh binary → no recompile, but live table re-asserted.
touch -t 202001010000 "$OMAC_HOTKEYS_SRC"   # backdate: binary is clearly newer
: > "$SWIFTC_LOG"; : > "$HOTKEYS_LOG"
omac::wm::disable_screenshot_hotkeys >/dev/null 2>&1
check "re-run exits 0" "0" "$?"
check "re-run skips recompile" "" "$(<"$SWIFTC_LOG")"
contains "re-run re-asserts live table" "28 0 30 0 184 0" "$(<"$HOTKEYS_LOG")"

# Missing compiler (no CLT) is non-fatal: prefs still written, warn only.
rm -f "$OMAC_HOTKEYS_BIN"
export OMAC_SWIFTC="/nonexistent/swiftc"
omac::wm::disable_screenshot_hotkeys >/dev/null 2>&1
check "no swiftc still exits 0" "0" "$?"

finish
