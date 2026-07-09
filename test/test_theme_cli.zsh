#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"

fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"; ln -s "$ROOT/bin" "$fake/bin"; ln -s "$ROOT/cmd" "$fake/cmd"
ln -s "$ROOT/fonts" "$fake/fonts"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
export OMAC_DEFAULT_THEME="tokyo-night"

export OMAC_THEMES="$(mktemp -d)/themes"
for t in tokyo-night nord; do
  mkdir -p "$OMAC_THEMES/$t/backgrounds"
  cat > "$OMAC_THEMES/$t/colors.toml" <<'EOF'
accent = "#7aa2f7"
foreground = "#a9b1d6"
background = "#1a1b26"
EOF
  print -r -- 'return {}' > "$OMAC_THEMES/$t/neovim.lua"
  print -r -- "{ \"name\": \"$t\", \"extension\": \"e.$t\"}" > "$OMAC_THEMES/$t/vscode.json"
  : > "$OMAC_THEMES/$t/backgrounds/1-w.jpg"
done
: > "$OMAC_THEMES/nord/light.mode"
_theme_stub_setup

bare="$(zsh "$fake/bin/omac" theme)"
contains "bare prints usage"   "Usage" "$bare"
contains "bare mentions set"   "set"   "$bare"

zsh "$fake/bin/omac" theme bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

zsh "$fake/bin/omac" theme set tokyo-night >/dev/null 2>&1
check "set exits 0" "0" "$?"
check "current reports theme" "tokyo-night" "$(zsh "$fake/bin/omac" theme current)"

listout="$(zsh "$fake/bin/omac" theme list)"
contains "list shows tokyo-night" "tokyo-night" "$listout"
contains "list marks current"     "tokyo-night" "$listout"
contains "list shows nord"        "nord"        "$listout"

zsh "$fake/bin/omac" theme reload >/dev/null 2>&1
check "reload exits 0" "0" "$?"
finish
