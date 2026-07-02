#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"
export OMAC_THEMES="$ROOT/themes"
source "$ROOT/lib/theme.zsh"

want=(tokyo-night catppuccin ethereal everforest gruvbox kanagawa nord ristretto rose-pine catppuccin-latte)
got="$(omac::theme::list_names | tr '\n' ' ')"
for t in $want; do
  contains "theme present: $t" "$t" "$got"
  check "$t has colors.toml" "yes" "$([[ -f "$ROOT/themes/$t/colors.toml" ]] && print yes || print no)"
  check "$t has neovim.lua"  "yes" "$([[ -f "$ROOT/themes/$t/neovim.lua" ]] && print yes || print no)"
  check "$t has btop.theme"  "yes" "$([[ -f "$ROOT/themes/$t/btop.theme" ]] && print yes || print no)"
  check "$t has vscode.json" "yes" "$([[ -f "$ROOT/themes/$t/vscode.json" ]] && print yes || print no)"
  check "$t palette parses"  "no"  "$([[ -z "$(omac::theme::toml_get "$ROOT/themes/$t/colors.toml" background)" ]] && print yes || print no)"
  check "$t has a background" "0"  "$(omac::theme::first_background "$t" >/dev/null; print $?)"
done
check "rose-pine is light"       "0" "$(omac::theme::is_light rose-pine; print $?)"
check "catppuccin-latte is light" "0" "$(omac::theme::is_light catppuccin-latte; print $?)"
check "no omarchy backgrounds" "" "$(find "$ROOT/themes" -iname '*omarchy*')"
finish
