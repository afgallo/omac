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
: > "$OMAC_THEMES/tokyo-night/backgrounds/01-wall.jpg"

export XDG_CONFIG_HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export OMAC_NVIM="$ROOT/nvim"        # omac-owned lang/dx specs (wire_nvim links these)
export HOME="$(mktemp -d)"
export OMAC_APPSUPPORT="$(mktemp -d)"
export OMAC_HOME="$ROOT"              # so theme.zsh loads the sibling font module
export OMAC_FONTS="$ROOT/fonts"       # font seam (ensure_ghostty_seam) reads the registry
export OMAC_DEFAULT_FONT="jetbrains-mono"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"

# Seed a deployed bordersrc so the live-reload step (which re-runs it) is
# observable via the `borders` stub. `theme` renders colors.sh; `wm` owns
# bordersrc, so it may pre-exist independently of a theme switch.
mkdir -p "$XDG_CONFIG_HOME/borders"
print -r -- '#!/usr/bin/env bash' >  "$XDG_CONFIG_HOME/borders/bordersrc"
print -r -- 'borders reload'       >> "$XDG_CONFIG_HOME/borders/bordersrc"
chmod +x "$XDG_CONFIG_HOME/borders/bordersrc"

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
# Font seam self-heals on set: ghostty config includes the font fragment and a
# default omac-font.conf is seeded (theme render no longer carries the font).
check "ghostty theme render has no font" "no" \
  "$([[ "$(<"$XDG_CONFIG_HOME/ghostty/omac-theme.conf")" == *font-family* ]] && print yes || print no)"
contains "ghostty config includes font conf" "omac-font.conf" "$(<"$XDG_CONFIG_HOME/ghostty/config")"
contains "default font seeded" 'font-family = "JetBrainsMono Nerd Font"' "$(<"$XDG_CONFIG_HOME/ghostty/omac-font.conf")"
contains "borders rendered" "ACTIVE_COLOR=0xff7aa2f7" "$(<"$XDG_CONFIG_HOME/borders/colors.sh")"
contains "tmux colors rendered" 'status-style "bg=#1a1b26,fg=#a9b1d6"' "$(<"$XDG_CONFIG_HOME/tmux/omac-theme.conf")"
contains "tmux live-reloaded" "source-file $XDG_CONFIG_HOME/tmux/omac-theme.conf" "$(<"$TMUX_LOG")"
# signal_app resolves PIDs from the ps stub's fake table (see theme_stubs.zsh):
# ghostty runs as a macOS app bundle whose proc name pkill can't match, so the
# reload must go through ps+kill, not pkill.
contains "ghostty live-reloaded via SIGUSR2" "-USR2 101" "$(<"$KILL_LOG")"
contains "nvim live-reloaded via SIGUSR1" "-USR1 303" "$(<"$KILL_LOG")"
present="$(grep -c " 404" "$KILL_LOG" || true)"
check "unrelated processes not signalled" "0" "$present"
contains "vscode colorTheme from vscode.json" "Tokyo Night" "$(<"$OMAC_APPSUPPORT/Code/User/settings.json")"
contains "appearance applied" "set dark mode to true" "$(<"$OSASCRIPT_LOG")"
contains "wallpaper applied" "01-wall.jpg" "$(<"$WALLPAPER_LOG")"
contains "borders reloaded" "reload" "$(<"$BORDERS_LOG")"
contains "selection persisted" 'OMAC_ACTIVE_THEME="tokyo-night"' "$(<"$OMAC_CONFIG/config.zsh")"
# `set` self-heals Neovim: scaffolds LazyVim and links the themed plugin even
# when the machine was never `install`-ed (regression: set-before-install).
check "nvim theme plugin linked on set" "1" \
  "$([[ -L "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-theme.lua" ]] && print 1 || print 0)"
check "nvim themes pack linked on set" "1" \
  "$([[ -L "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-themes.lua" ]] && print 1 || print 0)"

# Switching again updates the persisted value (no duplicate).
mkdir -p "$OMAC_THEMES/nord/backgrounds"; cp "$OMAC_THEMES/tokyo-night/colors.toml" "$OMAC_THEMES/nord/colors.toml"
print -r -- '{ "name": "Nord", "extension": "x"}' > "$OMAC_THEMES/nord/vscode.json"
: > "$OMAC_THEMES/nord/backgrounds/01-w.jpg"
omac::theme::set nord >/dev/null 2>&1
check "persist single line after re-set" "1" "$(grep -c OMAC_ACTIVE_THEME "$OMAC_CONFIG/config.zsh")"
finish
