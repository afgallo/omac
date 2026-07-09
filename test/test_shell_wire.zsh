#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"

# Isolate the deploy root and HOME so we touch no real rc files. Must happen
# BEFORE sourcing paths.zsh: its OMAC_ZSHRC/OMAC_BASHRC defaults derive from
# $HOME at source time, so a late stub would leave them aimed at the real home.
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"

source "$ROOT/lib/paths.zsh"
source "$ROOT/lib/common.zsh"

# Offline stubs: TPM bootstrap must never hit the network. `git clone` fakes a
# TPM checkout (with an install_plugins script); `tmux` is inert. GIT_LOG proves
# idempotency (clone happens once).
STUB="$(mktemp -d)"; export GIT_LOG="$(mktemp)"
cat > "$STUB/git" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$GIT_LOG"
if [[ "$1" == clone ]]; then
  dest="${@[-1]}"; mkdir -p "$dest/bin"
  printf '#!/bin/sh\nexit 0\n' > "$dest/bin/install_plugins"; chmod +x "$dest/bin/install_plugins"
fi
exit 0
SH
printf '#!/usr/bin/env zsh\nexit 0\n' > "$STUB/tmux"
chmod +x "$STUB/git" "$STUB/tmux"
export PATH="$STUB:$PATH"

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

# --- tmux: install wires the conf, bootstraps TPM, and renders theme colors --
tconf="$XDG_CONFIG_HOME/tmux/tmux.conf"
check "tmux.conf block written" "1" "$(grep -c '>>> omac >>>' "$tconf")"
contains "tmux.conf sources omac base" "source-file $OMAC_SHELL/tmux.conf" "$(<"$tconf")"
check "TPM cloned" "1" "$(test -d "$XDG_CONFIG_HOME/tmux/plugins/tpm" && print 1 || print 0)"
check "TPM cloned once" "1" "$(grep -c '^clone' "$GIT_LOG")"
contains "tmux theme rendered from active palette" 'status-style "bg=#1e1e2e,fg=#cdd6f4"' \
  "$(<"$XDG_CONFIG_HOME/tmux/omac-theme.conf")"

# Idempotent: a second deploy neither duplicates the block nor re-clones TPM.
omac::shell::deploy_tmux >/dev/null
check "tmux.conf block not duplicated" "1" "$(grep -c '>>> omac >>>' "$tconf")"
check "TPM not re-cloned" "1" "$(grep -c '^clone' "$GIT_LOG")"

# --- status -----------------------------------------------------------------
st="$(omac::shell::status)"
contains "status reports zshrc wired"   ".zshrc       yes" "$st"
contains "status reports starship seeded" "starship.toml yes" "$st"
contains "status reports tmux wired" "tmux.conf    yes" "$st"

finish
