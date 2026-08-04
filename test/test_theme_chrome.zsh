#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
export OMAC_CHROME_APP="$(mktemp -d)/Google Chrome.app"
DEFAULTS_LOG="$(mktemp)"

# Capture what `apply_chrome` writes instead of touching real Chrome preferences.
defaults() { print -r -- "$*" >> "$DEFAULTS_LOG"; }

# A dark theme with a background color.
mkdir -p "$OMAC_THEMES/dark"
cat > "$OMAC_THEMES/dark/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
EOF

# A light theme: same palette + the light.mode marker.
mkdir -p "$OMAC_THEMES/day"
cp "$OMAC_THEMES/dark/colors.toml" "$OMAC_THEMES/day/colors.toml"
: > "$OMAC_THEMES/day/light.mode"

source "$ROOT/lib/theme.zsh"

# Chrome absent → silent no-op (nothing written).
saved="$OMAC_CHROME_APP"; OMAC_CHROME_APP="/nonexistent/Google Chrome.app"
omac::theme::apply_chrome dark
check "no-op when Chrome absent" "0" "$(wc -l < "$DEFAULTS_LOG" | tr -d ' ')"
OMAC_CHROME_APP="$saved"; mkdir -p "$OMAC_CHROME_APP"

# Chrome present, dark theme → write both policies to com.google.Chrome.
omac::theme::apply_chrome dark
log="$(<"$DEFAULTS_LOG")"
contains "writes to the Chrome domain"      "com.google.Chrome"                 "$log"
contains "seeds theme color from background" "BrowserThemeColor -string #1a1b26" "$log"
contains "dark theme → color scheme dark"    "BrowserColorScheme -string dark"   "$log"
# Seed is the background, not accent/foreground.
check "seed is background, not accent" "0" "$(grep -c '7aa2f7' "$DEFAULTS_LOG")"

# Light theme → color scheme light.
: > "$DEFAULTS_LOG"
omac::theme::apply_chrome day
contains "light theme → color scheme light" "BrowserColorScheme -string light" "$(<"$DEFAULTS_LOG")"

finish
