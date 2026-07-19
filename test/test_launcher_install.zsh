#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

# Guard first: no Raycast app -> hard error hinting software install.
export OMAC_RAYCAST_APP="/nonexistent/Raycast.app"
# Pin the palette source out of the way so the palette step is a clean no-op
# here; its own flow is covered by test_launcher_palette.zsh.
export OMAC_PALETTE_SRC="/nonexistent/palette"
_launcher_stub_setup
source "$ROOT/lib/launcher.zsh"

omac::launcher::install >/dev/null 2>&1
check "install without Raycast exits 1" "1" "$?"
hint="$(omac::launcher::install 2>&1)"
contains "guard hints software install" "software install" "$hint"

# Now with Raycast present -> full flow runs.
export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"; mkdir -p "$OMAC_RAYCAST_APP"
export DEFAULTS_READ_OUT=""
: > "$DEFAULTS_LOG"; : > "$OPEN_LOG"; : > "$ACTIVATE_LOG"
omac::launcher::install >/dev/null 2>&1
check "install exits 0" "0" "$?"
contains "install freed ⌘Space"   "write com.apple.symbolichotkeys" "$(<"$DEFAULTS_LOG")"
contains "install applied live"   "-u"      "$(<"$ACTIVATE_LOG")"
contains "install opened Raycast" "Raycast" "$(<"$OPEN_LOG")"
finish
