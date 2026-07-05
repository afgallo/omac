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
  # Naming convention: every background is `NN-name.ext` (zero-padded), and each
  # theme has exactly one `01-` default. See docs/themes.
  bad=0; has01=0
  for bg in "$ROOT/themes/$t/backgrounds/"*(.N); do
    [[ "${bg:t}" == [0-9][0-9]-* ]] || (( bad++ ))
    [[ "${bg:t}" == 01-* ]] && (( has01++ ))
  done
  check "$t backgrounds all NN-named" "0" "$bad"
  check "$t has exactly one 01- default" "1" "$has01"
done
check "rose-pine is light"       "0" "$(omac::theme::is_light rose-pine; print $?)"
check "catppuccin-latte is light" "0" "$(omac::theme::is_light catppuccin-latte; print $?)"
check "no omarchy backgrounds" "" "$(find "$ROOT/themes" -iname '*omarchy*')"
# apps.toml must not carry dead `zed` keys (Zed theming is out of scope).
zedhits=0
for af in "$ROOT"/themes/*/apps.toml(N); do
  grep -Eq '^[[:space:]]*zed[[:space:]]*=' "$af" && (( zedhits++ ))
done
check "no apps.toml has a zed key" "0" "$zedhits"
finish
