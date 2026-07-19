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

check "hex_to_argb default alpha" "0xff1a1b26" "$(omac::theme::hex_to_argb '#1a1b26')"
check "hex_to_argb custom alpha"  "0x401a1b26" "$(omac::theme::hex_to_argb '#1a1b26' 40)"

gconf="$(mktemp)"
omac::theme::render_ghostty named "$gconf"
contains "ghostty uses built-in name" "theme = tokyonight" "$(<"$gconf")"

omac::theme::render_ghostty palette "$gconf"
gout="$(<"$gconf")"
check "ghostty palette has no theme= line" "no" "$([[ "$gout" == *"theme ="* ]] && print yes || print no)"
contains "ghostty palette background" "background = 1a1b26" "$gout"
contains "ghostty palette foreground" "foreground = a9b1d6" "$gout"
contains "ghostty palette color0"     "palette = 0=#32344a" "$gout"

bd="$(mktemp)"
omac::theme::render_borders named "$bd"
bdout="$(<"$bd")"
contains "borders active color (accent, opaque)"    "ACTIVE_COLOR=0xff7aa2f7"   "$bdout"
contains "borders inactive color (fg, translucent)" "INACTIVE_COLOR=0x40a9b1d6" "$bdout"

# --- tmux status colors ------------------------------------------------------
# 'named' has no color8, so pane-border falls back to foreground.
tm="$(mktemp)"
omac::theme::render_tmux named "$tm"
tmout="$(<"$tm")"
contains "tmux status uses bg+fg"              'set -g status-style "bg=#1a1b26,fg=#a9b1d6"' "$tmout"
contains "tmux session name is accent"         'status-left-style "fg=#7aa2f7,bold"' "$tmout"
contains "tmux inactive windows dim fg"        'window-status-style "fg=#a9b1d6,dim"' "$tmout"
contains "tmux active window accent+underline" 'window-status-current-style "fg=#7aa2f7,bold,underscore"' "$tmout"
contains "tmux right side is dim chrome"        'status-right-style "fg=#a9b1d6,dim"' "$tmout"
contains "tmux active border is accent"         'pane-active-border-style "fg=#7aa2f7"' "$tmout"
contains "tmux takes raw hex (no 0xAA)"         'mode-style "bg=#7aa2f7,fg=#1a1b26"' "$tmout"

bg="$(omac::theme::first_background named)"
check "first background skips omarchy" "1-first.jpg" "${bg:t}"
bg="$(omac::theme::first_background palette)"
check "first background single" "0-only.png" "${bg:t}"

# --- Starship palette --------------------------------------------------------
# Fixture 'named' defines accent + color0 + color15; other colors are absent, so
# this also proves a sparse palette still returns 0 and emits the keys it has.
pal="$(omac::theme::starship_palette named)"
check "starship_palette exits 0 with sparse colors" "0" "$?"
contains "starship palette header" "[palettes.omac]"    "$pal"
contains "starship palette accent" 'accent = "#7aa2f7"' "$pal"
contains "starship palette black=color0" 'black = "#32344a"' "$pal"

# render_starship no-ops when starship.toml is absent (shell not installed yet).
export XDG_CONFIG_HOME="$(mktemp -d)"
omac::theme::render_starship named
check "render_starship no-op without file" "0" "$(test -f "$XDG_CONFIG_HOME/starship.toml" && print 1 || print 0)"

# With a seeded starship.toml carrying a managed block, render replaces it.
st="$XDG_CONFIG_HOME/starship.toml"
{ print 'palette = "omac"'; print "# >>> omac >>>"; print "[palettes.omac]"; print 'accent = "placeholder"'; print "# <<< omac <<<"; } > "$st"
omac::theme::render_starship named >/dev/null
contains "render replaced palette block" 'accent = "#7aa2f7"' "$(<"$st")"
check "render did not duplicate block" "1" "$(grep -c '>>> omac >>>' "$st")"
check "render dropped placeholder" "0" "$(grep -c 'placeholder' "$st")"
finish
