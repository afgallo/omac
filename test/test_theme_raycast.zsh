#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"
OPEN_LOG="$(mktemp)"

# Capture the deeplink `apply_raycast` opens instead of launching Raycast.
open() { print -r -- "$*" >> "$OPEN_LOG"; }

# A dark theme with a full ANSI palette.
mkdir -p "$OMAC_THEMES/dark"
cat > "$OMAC_THEMES/dark/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
color1 = "#f7768e"
color2 = "#9ece6a"
color3 = "#e0af68"
color4 = "#7aa2f7"
color5 = "#ad8ee6"
color8 = "#444b6a"
color11 = "#ff9e64"
color13 = "#bb9af7"
EOF

# A light theme (light.mode marker present).
mkdir -p "$OMAC_THEMES/day"
cp "$OMAC_THEMES/dark/colors.toml" "$OMAC_THEMES/day/colors.toml"
: > "$OMAC_THEMES/day/light.mode"

source "$ROOT/lib/theme.zsh"

# Raycast absent → silent no-op (nothing opened).
saved="$OMAC_RAYCAST_APP"; OMAC_RAYCAST_APP="/nonexistent/Raycast.app"
omac::theme::apply_raycast dark
check "no-op when Raycast absent" "0" "$(wc -l < "$OPEN_LOG" | tr -d ' ')"
OMAC_RAYCAST_APP="$saved"; mkdir -p "$OMAC_RAYCAST_APP"

# Raycast present → open a raycast://theme deeplink.
omac::theme::apply_raycast dark
url="$(<"$OPEN_LOG")"
contains "opens the theme deeplink"   "raycast://theme?name=omac" "$url"
contains "marks dark appearance"      "appearance=dark"           "$url"
contains "encodes background as %23"  "colors=%231a1b26"          "$url"
contains "orange from color11"        "%23ff9e64"                 "$url"
contains "text from foreground"       "%23a9b1d6"                 "$url"

# Light theme → appearance=light.
: > "$OPEN_LOG"
omac::theme::apply_raycast day
contains "marks light appearance" "appearance=light" "$(<"$OPEN_LOG")"

# Ordering: exactly the 12 positional colors, background repeated for secondary.
: > "$OPEN_LOG"
omac::theme::apply_raycast dark
raw="$(<"$OPEN_LOG")"
colors="${raw##*colors=}"
parts=( "${(s:,:)colors}" )
check "twelve positional colors" "12" "${#parts}"
finish
