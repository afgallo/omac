#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"

# Isolated OMAC_HOME wired to the real lib/bin/cmd (as in test_theme_cli.zsh).
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"; ln -s "$ROOT/bin" "$fake/bin"; ln -s "$ROOT/cmd" "$fake/cmd"
ln -s "$ROOT/fonts" "$fake/fonts"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"

export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/multi/backgrounds"
: > "$OMAC_THEMES/multi/backgrounds/01-a.jpg"
: > "$OMAC_THEMES/multi/backgrounds/02-b.jpg"
: > "$OMAC_THEMES/multi/backgrounds/03-c.png"
_theme_stub_setup

# Establish the active theme (what `omac theme set` leaves behind).
ln -sfn "$OMAC_THEMES/multi" "$OMAC_CURRENT"

# Bare command prints usage and the current wallpaper.
bare="$(zsh "$fake/bin/omac" wallpaper)"
contains "bare prints usage"  "Usage" "$bare"
contains "bare mentions next" "next"  "$bare"

# Unknown subcommand exits 1 (falls back to the flat dispatcher).
zsh "$fake/bin/omac" wallpaper bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

# current before any cycle -> the theme default.
check "current is 01 by default" "01-a.jpg" "$(zsh "$fake/bin/omac" wallpaper current)"

# next cycles across invocations (pointer persisted in config.zsh, re-sourced
# by bin/omac on each run).
zsh "$fake/bin/omac" wallpaper next >/dev/null 2>&1
check "after 1st next -> 02" "02-b.jpg" "$(zsh "$fake/bin/omac" wallpaper current)"
zsh "$fake/bin/omac" wallpaper next >/dev/null 2>&1
check "after 2nd next -> 03" "03-c.png" "$(zsh "$fake/bin/omac" wallpaper current)"
zsh "$fake/bin/omac" wallpaper next >/dev/null 2>&1
check "3rd next wraps -> 01" "01-a.jpg" "$(zsh "$fake/bin/omac" wallpaper current)"

# list shows all backgrounds and marks the active one.
listout="$(zsh "$fake/bin/omac" wallpaper list)"
contains "list shows 01" "01-a.jpg" "$listout"
contains "list shows 03" "03-c.png" "$listout"
contains "list marks active" "● 01-a.jpg" "$listout"

finish
