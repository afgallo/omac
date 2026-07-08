#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
# Two themes; one extension shared -> must dedupe.
for t in tokyo-night catppuccin; do
  mkdir -p "$OMAC_THEMES/$t/backgrounds"
  cat > "$OMAC_THEMES/$t/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
EOF
  print -r -- 'return {}' > "$OMAC_THEMES/$t/neovim.lua"
  : > "$OMAC_THEMES/$t/backgrounds/1-w.jpg"
done
print -r -- '{ "name": "Tokyo Night", "extension": "enkia.tokyo-night"}' > "$OMAC_THEMES/tokyo-night/vscode.json"
print -r -- '{ "name": "Catppuccin Mocha", "extension": "catppuccin.catppuccin-vsc"}' > "$OMAC_THEMES/catppuccin/vscode.json"

export XDG_CONFIG_HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export OMAC_DEFAULT_THEME="tokyo-night"
export HOME="$(mktemp -d)"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"

omac::theme::install_extensions >/dev/null 2>&1
clog="$(<"$CODE_LOG")"
contains "installs tokyo ext"      "install-extension enkia.tokyo-night" "$clog"
contains "installs catppuccin ext" "install-extension catppuccin.catppuccin-vsc" "$clog"
check "extensions deduped (2 distinct)" "2" "$(grep -c install-extension "$CODE_LOG")"

omac::theme::wire >/dev/null 2>&1
contains "ghostty include wired" "config-file" "$(<"$XDG_CONFIG_HOME/ghostty/config")"
present="$([[ -L "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-theme.lua" ]] && print yes || print no)"
check "neovim plugin pointer linked" "yes" "$present"

omac::theme::install >/dev/null 2>&1
check "install exits 0" "0" "$?"
check "install set default (current)" "tokyo-night" "${$(readlink "$OMAC_CURRENT"):t}"
finish
