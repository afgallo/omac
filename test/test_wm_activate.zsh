#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

# config_dir defaults to $HOME/.config; keep XDG aligned so the deployed
# bordersrc (which sources $HOME/.config/borders/colors.sh) resolves.
export HOME="$(mktemp -d)"
export XDG_CONFIG_HOME="$HOME/.config"

# Fixture borders tree: bordersrc sources its colors and invokes the `borders`
# stub, so re-running it (the reload path) leaves a trace in BORDERS_LOG.
export OMAC_WM="$(mktemp -d)/wm"
mkdir -p "$OMAC_WM/borders"
print -r -- '#!/usr/bin/env bash'                       >  "$OMAC_WM/borders/bordersrc"
print -r -- 'source "$HOME/.config/borders/colors.sh"'  >> "$OMAC_WM/borders/bordersrc"
print -r -- 'borders active_color="$ACTIVE_COLOR"'      >> "$OMAC_WM/borders/bordersrc"
print -r -- 'export ACTIVE_COLOR=0xffabcdef'            >  "$OMAC_WM/borders/colors.sh"

source "$ROOT/test/wm_stubs.zsh"
_wm_stub_setup
source "$ROOT/lib/wm.zsh"

# Deploy so the bordersrc reload path has something executable to run.
omac::wm::deploy_borders >/dev/null 2>&1

omac::wm::activate >/dev/null 2>&1
check "activate exits 0" "0" "$?"
contains "activate starts borders service"   "services start borders" "$(<"$BREW_LOG")"
contains "activate opens Accessibility pane"  "Privacy_Accessibility"  "$(<"$OPEN_LOG")"

omac::wm::reload >/dev/null 2>&1
check "reload exits 0" "0" "$?"
contains "reload reloads aerospace" "reload-config" "$(<"$AEROSPACE_LOG")"
contains "reload reloads borders"   "active_color"  "$(<"$BORDERS_LOG")"
finish
