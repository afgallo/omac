#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/wm_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_WM="$(mktemp -d)/wm"
mkdir -p "$OMAC_WM"
cat > "$OMAC_WM/tweaks.conf" <<'EOF'
# a comment
NSGlobalDomain KeyRepeat int 2
com.apple.dock autohide bool true
EOF

_wm_stub_setup
source "$ROOT/lib/wm.zsh"

omac::wm::apply_tweaks >/dev/null 2>&1
check "apply_tweaks exits 0" "0" "$?"
dlog="$(<"$DEFAULTS_LOG")"
contains "wrote KeyRepeat" "write NSGlobalDomain KeyRepeat -int 2" "$dlog"
contains "wrote dock autohide" "write com.apple.dock autohide -bool true" "$dlog"
check "comment line skipped" "no" "$([[ "$dlog" == *comment* ]] && print yes || print no)"

contains "caps remapped via hidutil" "UserKeyMapping" "$(<"$HIDUTIL_LOG")"

# apply_tweaks also frees macOS's ⇧⌘3/4/5 screenshot hotkeys so they stop
# clobbering AeroSpace's cmd-shift-3/4/5 window-move binds.
contains "freed ⇧⌘3/4/5 screenshots" "write com.apple.symbolichotkeys" "$dlog"
contains "applied hotkey change live" "28 0 30 0 184 0" "$(<"$HOTKEYS_LOG")"

# Persistence: a LaunchAgent must be written and bootstrapped so the remap
# survives a reboot (hidutil alone is session-scoped).
plist="$OMAC_LAUNCHAGENTS/com.omac.capsescape.plist"
check "caps LaunchAgent written" "yes" "$([[ -f "$plist" ]] && print yes || print no)"
contains "LaunchAgent runs hidutil"   "hidutil"        "$(<"$plist")"
contains "LaunchAgent re-applies map" "UserKeyMapping" "$(<"$plist")"
contains "LaunchAgent bootstrapped"   "bootstrap"      "$(<"$LAUNCHCTL_LOG")"
finish
