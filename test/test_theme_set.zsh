#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/tokyo-night/backgrounds"
cat > "$OMAC_THEMES/tokyo-night/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
color0 = "#32344a"
EOF
print -r -- 'ghostty = "tokyonight"' > "$OMAC_THEMES/tokyo-night/apps.toml"
print -r -- '{ "name": "Tokyo Night", "extension": "enkia.tokyo-night"}' > "$OMAC_THEMES/tokyo-night/vscode.json"
print -r -- 'return {}' > "$OMAC_THEMES/tokyo-night/neovim.lua"
print -r -- 'theme[main_bg]="#1a1b26"' > "$OMAC_THEMES/tokyo-night/btop.theme"
: > "$OMAC_THEMES/tokyo-night/backgrounds/1-wall.jpg"

export XDG_CONFIG_HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export HOME="$(mktemp -d)"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"

# Unknown theme -> hard error.
omac::theme::set nope >/dev/null 2>&1
check "unknown theme exits 1" "1" "$?"

# Real switch.
omac::theme::set tokyo-night >/dev/null 2>&1
check "set exits 0" "0" "$?"
check "current symlink points at theme" "tokyo-night" "${$(readlink "$OMAC_CURRENT"):t}"
present="$([[ -f "$XDG_CONFIG_HOME/ghostty/omac-theme.conf" ]] && print yes || print no)"
check "ghostty fragment written" "yes" "$present"
contains "ghostty theme name" "theme = tokyonight" "$(<"$XDG_CONFIG_HOME/ghostty/omac-theme.conf")"
contains "sketchybar rendered" "BAR_COLOR=0xff1a1b26" "$(<"$XDG_CONFIG_HOME/sketchybar/colors.sh")"
contains "vscode colorTheme from vscode.json" "Tokyo Night" "$(<"$XDG_CONFIG_HOME/Code/User/settings.json")"
contains "appearance applied" "set dark mode to true" "$(<"$OSASCRIPT_LOG")"
contains "wallpaper applied" "1-wall.jpg" "$(<"$OSASCRIPT_LOG")"
contains "sketchybar reloaded" "--reload" "$(<"$SKETCHYBAR_LOG")"
contains "selection persisted" 'OMAC_ACTIVE_THEME="tokyo-night"' "$(<"$OMAC_CONFIG/config.zsh")"

# Switching again updates the persisted value (no duplicate).
mkdir -p "$OMAC_THEMES/nord/backgrounds"; cp "$OMAC_THEMES/tokyo-night/colors.toml" "$OMAC_THEMES/nord/colors.toml"
print -r -- '{ "name": "Nord", "extension": "x"}' > "$OMAC_THEMES/nord/vscode.json"
: > "$OMAC_THEMES/nord/backgrounds/1-w.jpg"
omac::theme::set nord >/dev/null 2>&1
check "persist single line after re-set" "1" "$(grep -c OMAC_ACTIVE_THEME "$OMAC_CONFIG/config.zsh")"
finish
