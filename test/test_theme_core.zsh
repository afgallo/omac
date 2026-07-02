#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

# Fixture theme tree.
export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/aaa" "$OMAC_THEMES/zzz"
print -r -- 'accent = "#7aa2f7"' >  "$OMAC_THEMES/aaa/colors.toml"
print -r -- 'background = "#1a1b26"' >> "$OMAC_THEMES/aaa/colors.toml"
: > "$OMAC_THEMES/zzz/light.mode"

# Isolate config/current.
export XDG_CONFIG_HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export OMAC_ACTIVE_THEME=""

source "$ROOT/lib/theme.zsh"

check "config_dir honors XDG" "$XDG_CONFIG_HOME" "$(omac::theme::config_dir)"
check "toml_get reads accent" "#7aa2f7" "$(omac::theme::toml_get "$OMAC_THEMES/aaa/colors.toml" accent)"
check "toml_get reads background" "#1a1b26" "$(omac::theme::toml_get "$OMAC_THEMES/aaa/colors.toml" background)"
check "toml_get missing key empty" "" "$(omac::theme::toml_get "$OMAC_THEMES/aaa/colors.toml" nope)"

check "list_names sorted" "aaa
zzz" "$(omac::theme::list_names)"
check "is_theme yes" "0" "$(omac::theme::is_theme aaa; print $?)"
check "is_theme no" "1" "$(omac::theme::is_theme nope; print $?)"
check "is_light yes" "0" "$(omac::theme::is_light zzz; print $?)"
check "is_light no" "1" "$(omac::theme::is_light aaa; print $?)"

check "current none -> 1" "1" "$(omac::theme::current; print $?)"
ln -sfn "$OMAC_THEMES/aaa" "$OMAC_CURRENT"
check "current resolves symlink" "aaa" "$(omac::theme::current)"
finish
