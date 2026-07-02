#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/dark/backgrounds" "$OMAC_THEMES/lite/backgrounds"
: > "$OMAC_THEMES/dark/backgrounds/omarchy.png"
: > "$OMAC_THEMES/dark/backgrounds/1-wall.jpg"
: > "$OMAC_THEMES/lite/light.mode"
: > "$OMAC_THEMES/lite/backgrounds/1-day.jpg"

export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
export OMAC_APPSUPPORT="$(mktemp -d)"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"

omac::theme::apply_appearance dark >/dev/null 2>&1
contains "dark mode true" "set dark mode to true" "$(<"$OSASCRIPT_LOG")"
: > "$OSASCRIPT_LOG"
omac::theme::apply_appearance lite >/dev/null 2>&1
contains "light mode false" "set dark mode to false" "$(<"$OSASCRIPT_LOG")"

: > "$OSASCRIPT_LOG"
omac::theme::apply_wallpaper dark >/dev/null 2>&1
wlog="$(<"$OSASCRIPT_LOG")"
contains "wallpaper set to first bg" "1-wall.jpg" "$wlog"
check "wallpaper never omarchy" "no" "$([[ "$wlog" == *omarchy* ]] && print yes || print no)"

# VS Code: create when absent, replace when present.
vs="$OMAC_APPSUPPORT/Code/User/settings.json"
omac::theme::apply_vscode "Tokyo Night" >/dev/null 2>&1
contains "vscode created with theme" '"workbench.colorTheme": "Tokyo Night"' "$(<"$vs")"
omac::theme::apply_vscode "Nord" >/dev/null 2>&1
vsout="$(<"$vs")"
contains "vscode value replaced" '"workbench.colorTheme": "Nord"' "$vsout"
check "vscode no duplicate key" "1" "$(grep -c 'workbench.colorTheme' "$vs")"
finish
