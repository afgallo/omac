#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
source "$ROOT/lib/paths.zsh"
source "$ROOT/lib/common.zsh"

# Isolate the deploy root and HOME so we touch no real rc files.
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"

# Fixture shell fragment tree + a starship.toml with a managed palette block,
# isolated from the repo's real shell/.
export OMAC_SHELL="$(mktemp -d)/shell"
mkdir -p "$OMAC_SHELL"
print -r -- "# zsh fragment"  > "$OMAC_SHELL/omac.zsh"
print -r -- "# bash fragment" > "$OMAC_SHELL/omac.bash"
{
  print -r -- 'palette = "omac"'
  print -r -- "# >>> omac >>>"
  print -r -- "[palettes.omac]"
  print -r -- "# <<< omac <<<"
} > "$OMAC_SHELL/starship.toml"

# Fixture theme so render_starship (called by install) has a palette to paint.
export OMAC_THEMES="$(mktemp -d)/themes"
mkdir -p "$OMAC_THEMES/catppuccin"
cat > "$OMAC_THEMES/catppuccin/colors.toml" <<'EOF'
accent = "#89b4fa"
foreground = "#cdd6f4"
background = "#1e1e2e"
color1 = "#f38ba8"
color4 = "#89b4fa"
EOF

source "$ROOT/lib/shell.zsh"

check "config_dir honors XDG" "$XDG_CONFIG_HOME" "$(omac::shell::config_dir)"
check "fragment path" "$OMAC_SHELL/omac.zsh" "$(omac::shell::fragment zsh)"

# --- wiring: adds a managed block that sources the fragment ------------------
omac::shell::wire_rc "$HOME/.zshrc" zsh >/dev/null
check "zshrc block written" "1" "$(grep -c '>>> omac >>>' "$HOME/.zshrc")"
contains "zshrc sources fragment" "source \"$OMAC_SHELL/omac.zsh\"" "$(<"$HOME/.zshrc")"

# Idempotent: a second wire does not duplicate the block.
omac::shell::wire_rc "$HOME/.zshrc" zsh >/dev/null
check "zshrc block not duplicated" "1" "$(grep -c '>>> omac >>>' "$HOME/.zshrc")"

# A missing fragment is refused, not silently wired.
omac::shell::wire_rc "$HOME/.fishrc" fish >/dev/null 2>&1
check "unknown-shell fragment refused" "1" "$?"
check "no rc written for missing fragment" "0" "$(test -f "$HOME/.fishrc" && print 1 || print 0)"

# --- starship seeding: copy once, never clobber -----------------------------
omac::shell::deploy_starship >/dev/null
check "starship.toml seeded" "1" "$(test -f "$XDG_CONFIG_HOME/starship.toml" && print 1 || print 0)"

# Seeding is non-destructive: an edited starship.toml is left untouched.
print -r -- "# user edit" >> "$XDG_CONFIG_HOME/starship.toml"
before="$(<"$XDG_CONFIG_HOME/starship.toml")"
omac::shell::deploy_starship >/dev/null
check "starship.toml not clobbered" "$before" "$(<"$XDG_CONFIG_HOME/starship.toml")"

# --- full install wires both shells and paints the active-theme palette ------
export OMAC_CURRENT="$OMAC_CONFIG/current"
export OMAC_CONFIG="$(mktemp -d)/omac"
mkdir -p "$OMAC_CONFIG"
ln -sfn "$OMAC_THEMES/catppuccin" "$OMAC_CONFIG/current"
export OMAC_CURRENT="$OMAC_CONFIG/current"
rm -f "$HOME/.zshrc" "$HOME/.bashrc" "$XDG_CONFIG_HOME/starship.toml"

omac::shell::install >/dev/null
check "install wired zshrc"  "1" "$(grep -c '>>> omac >>>' "$HOME/.zshrc")"
check "install wired bashrc" "1" "$(grep -c '>>> omac >>>' "$HOME/.bashrc")"
contains "install painted palette from active theme" 'accent = "#89b4fa"' "$(<"$XDG_CONFIG_HOME/starship.toml")"

# --- status -----------------------------------------------------------------
st="$(omac::shell::status)"
contains "status reports zshrc wired"   ".zshrc       yes" "$st"
contains "status reports starship seeded" "starship.toml yes" "$st"

finish
