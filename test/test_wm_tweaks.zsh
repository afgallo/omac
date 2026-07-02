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
finish
