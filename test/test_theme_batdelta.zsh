#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
# Theme WITH a bat name.
mkdir -p "$OMAC_THEMES/named"
print -r -- 'ghostty = "tokyonight"' >  "$OMAC_THEMES/named/apps.toml"
print -r -- 'bat = "TwoDark"'         >> "$OMAC_THEMES/named/apps.toml"
# Theme WITHOUT a bat name.
mkdir -p "$OMAC_THEMES/plain"
print -r -- 'ghostty = "x"' > "$OMAC_THEMES/plain/apps.toml"

export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"
batcfg="$XDG_CONFIG_HOME/bat/config"

# No bat name -> neither target is touched (checked first, before any file exists).
omac::theme::apply_bat plain >/dev/null 2>&1
omac::theme::apply_delta plain >/dev/null 2>&1
check "no bat config for unnamed theme" "no" "$([[ -f "$batcfg" ]] && print yes || print no)"
check "delta untouched for unnamed theme" "" "$(<"$GIT_LOG")"

# bat: named theme writes a managed --theme block.
omac::theme::apply_bat named >/dev/null 2>&1
contains "bat config has theme" '--theme="TwoDark"' "$(<"$batcfg")"

# delta: named theme calls git config with the same name.
omac::theme::apply_delta named >/dev/null 2>&1
contains "delta syntax-theme set" 'config --global delta.syntax-theme TwoDark' "$(<"$GIT_LOG")"

# Re-applying replaces (no duplicate --theme line).
omac::theme::apply_bat named >/dev/null 2>&1
check "bat theme single line after re-apply" "1" "$(grep -c -- '--theme=' "$batcfg")"
finish
