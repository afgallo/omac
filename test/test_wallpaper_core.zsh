#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

# A theme with several backgrounds (cycle) and one with a single background.
export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/multi/backgrounds" "$OMAC_THEMES/single/backgrounds"
: > "$OMAC_THEMES/multi/backgrounds/03-c.png"
: > "$OMAC_THEMES/multi/backgrounds/01-a.jpg"
: > "$OMAC_THEMES/multi/backgrounds/02-b.jpg"
: > "$OMAC_THEMES/multi/backgrounds/omarchy.png"   # must be skipped
: > "$OMAC_THEMES/single/backgrounds/01-only.jpg"

export XDG_CONFIG_HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export HOME="$(mktemp -d)"
export OMAC_APPSUPPORT="$(mktemp -d)"
export OMAC_HOME="$ROOT"              # so wallpaper.zsh loads the sibling theme/font modules
export OMAC_FONTS="$ROOT/fonts"
_theme_stub_setup
source "$ROOT/lib/wallpaper.zsh"

# Active theme resolves via the current symlink (as after `omac theme set`).
ln -sfn "$OMAC_THEMES/multi" "$OMAC_CURRENT"

# --- backgrounds listing (cycle order, omarchy skipped) ----------------------
bgs="$(omac::theme::backgrounds multi)"
check "backgrounds count (omarchy skipped)" "3" "$(print -r -- "$bgs" | grep -c .)"
check "backgrounds sorted, 01 first" "01-a.jpg" "$(print -r -- "$bgs" | head -1 | xargs basename)"
check "no omarchy in cycle" "no" "$([[ "$bgs" == *omarchy* ]] && print yes || print no)"

# --- current: empty pointer => theme default (01-) ---------------------------
export OMAC_ACTIVE_WALLPAPER=""
check "current defaults to 01-" "01-a.jpg" "$(omac::wallpaper::current)"

# --- next: advances, applies, persists, wraps --------------------------------
: > "$WALLPAPER_LOG"
omac::wallpaper::next >/dev/null 2>&1
contains "next applies 02 via wallpaper CLI" "02-b.jpg" "$(<"$WALLPAPER_LOG")"
check "next persisted 02" "02-b.jpg" "$OMAC_ACTIVE_WALLPAPER"
contains "next persisted to config.zsh" 'OMAC_ACTIVE_WALLPAPER="02-b.jpg"' "$(<"$OMAC_CONFIG/config.zsh")"
check "current now reports 02" "02-b.jpg" "$(omac::wallpaper::current)"

omac::wallpaper::next >/dev/null 2>&1
check "next advances to 03" "03-c.png" "$OMAC_ACTIVE_WALLPAPER"

: > "$WALLPAPER_LOG"
omac::wallpaper::next >/dev/null 2>&1
check "next wraps back to 01" "01-a.jpg" "$OMAC_ACTIVE_WALLPAPER"
contains "wrap applied 01" "01-a.jpg" "$(<"$WALLPAPER_LOG")"

# --- current: stale pointer (not in this theme) => default -------------------
export OMAC_ACTIVE_WALLPAPER="99-gone.jpg"
check "stale pointer falls back to default" "01-a.jpg" "$(omac::wallpaper::current)"

# --- list marks the active one ----------------------------------------------
export OMAC_ACTIVE_WALLPAPER="02-b.jpg"
listout="$(omac::wallpaper::list)"
check "list shows all three" "3" "$(print -r -- "$listout" | grep -c .)"
contains "list marks active with dot" "● 02-b.jpg" "$listout"
check "only one active marker" "1" "$(print -r -- "$listout" | grep -c '●')"

# --- single-background theme: next is a no-op --------------------------------
ln -sfn "$OMAC_THEMES/single" "$OMAC_CURRENT"
export OMAC_ACTIVE_WALLPAPER=""
: > "$WALLPAPER_LOG"
omac::wallpaper::next >/dev/null 2>&1
check "single theme: next exits 0" "0" "$?"
check "single theme: nothing applied" "" "$(<"$WALLPAPER_LOG")"

finish
