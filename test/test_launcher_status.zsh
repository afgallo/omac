#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"; mkdir -p "$OMAC_RAYCAST_APP"
_launcher_stub_setup
source "$ROOT/lib/launcher.zsh"

# activate opens Raycast and the panes, and prints the manual checklist.
out="$(omac::launcher::activate 2>&1)"
contains "activate opened Raycast"        "Raycast"              "$(<"$OPEN_LOG")"
contains "activate opened Accessibility"  "Privacy_Accessibility" "$(<"$OPEN_LOG")"
contains "activate lists manual steps"    "Clipboard History"    "$out"

# status reports the three facts and performs no writes.
export DEFAULTS_READ_OUT=""
: > "$DEFAULTS_LOG"
out="$(omac::launcher::status)"
contains "status shows Raycast installed" "Raycast installed" "$out"
contains "status shows running row"       "Raycast running"   "$out"
contains "status shows hotkey row"        "⌘Space freed"      "$out"
wrote="$([[ "$(<"$DEFAULTS_LOG")" == *write* ]] && print yes || print no)"
check "status performs no defaults write" "no" "$wrote"
finish
