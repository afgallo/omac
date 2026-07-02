#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"

# Theme A: has a ghostty built-in name in apps.toml.
mkdir -p "$OMAC_THEMES/named/backgrounds"
cat > "$OMAC_THEMES/named/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
cursor = "#c0caf5"
selection_foreground = "#c0caf5"
selection_background = "#7aa2f7"
color0 = "#32344a"
color15 = "#acb0d0"
EOF
print -r -- 'ghostty = "tokyonight"' > "$OMAC_THEMES/named/apps.toml"
: > "$OMAC_THEMES/named/backgrounds/omarchy.png"
: > "$OMAC_THEMES/named/backgrounds/1-first.jpg"
: > "$OMAC_THEMES/named/backgrounds/2-second.jpg"

# Theme B: no apps.toml -> ghostty renders from palette.
mkdir -p "$OMAC_THEMES/palette/backgrounds"
cp "$OMAC_THEMES/named/colors.toml" "$OMAC_THEMES/palette/colors.toml"
: > "$OMAC_THEMES/palette/backgrounds/0-only.png"

source "$ROOT/lib/theme.zsh"

check "hex_to_sb" "0xff1a1b26" "$(omac::theme::hex_to_sb '#1a1b26')"

gconf="$(mktemp)"
omac::theme::render_ghostty named "$gconf"
contains "ghostty uses built-in name" "theme = tokyonight" "$(<"$gconf")"

omac::theme::render_ghostty palette "$gconf"
gout="$(<"$gconf")"
check "ghostty palette has no theme= line" "no" "$([[ "$gout" == *"theme ="* ]] && print yes || print no)"
contains "ghostty palette background" "background = 1a1b26" "$gout"
contains "ghostty palette foreground" "foreground = a9b1d6" "$gout"
contains "ghostty palette color0"     "palette = 0=#32344a" "$gout"

sb="$(mktemp)"
omac::theme::render_sketchybar named "$sb"
sbout="$(<"$sb")"
contains "sketchybar bar color"   "BAR_COLOR=0xff1a1b26"   "$sbout"
contains "sketchybar label color" "LABEL_COLOR=0xffa9b1d6" "$sbout"
contains "sketchybar accent"      "ACCENT_COLOR=0xff7aa2f7" "$sbout"

bg="$(omac::theme::first_background named)"
check "first background skips omarchy" "1-first.jpg" "${bg:t}"
bg="$(omac::theme::first_background palette)"
check "first background single" "0-only.png" "${bg:t}"
finish
