#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"

fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"; ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"; ln -s "$ROOT/fonts" "$fake/fonts"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
export OMAC_APPSUPPORT="$(mktemp -d)"
_theme_stub_setup

# Stub brew so warn_if_missing stays offline and deterministic.
bdir="$(mktemp -d)"; print -r -- $'#!/usr/bin/env zsh\nexit 0' > "$bdir/brew"
chmod +x "$bdir/brew"; export PATH="$bdir:$PATH"

# Pre-seed a theme selection: proves persisting a font does NOT clobber it (both
# live in the one managed block of config.zsh).
{ print "# >>> omac >>>"; print 'export OMAC_ACTIVE_THEME="nord"'; print "# <<< omac <<<"; } \
  > "$OMAC_CONFIG/config.zsh"

O="$fake/bin/omac"
fconf="$XDG_CONFIG_HOME/ghostty/omac-font.conf"
gconf="$XDG_CONFIG_HOME/ghostty/config"
vscode="$OMAC_APPSUPPORT/Code/User/settings.json"

bare="$(zsh "$O" font)"
contains "bare prints usage"  "Usage"       "$bare"
contains "bare mentions set"  "set <name>"  "$bare"

zsh "$O" font bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

listout="$(zsh "$O" font list)"
contains "list shows slug"           "jetbrains-mono"          "$listout"
contains "list shows family"         "JetBrainsMono Nerd Font" "$listout"
contains "list marks default current" "● jetbrains-mono"       "$listout"

# Switch to hack at size 15.
zsh "$O" font set hack 15 >/dev/null 2>&1
check "set exits 0" "0" "$?"
contains "ghostty font-family" 'font-family = "Hack Nerd Font"' "$(<"$fconf")"
contains "ghostty font-size"   "font-size = 15"                 "$(<"$fconf")"
contains "ghostty includes theme conf" "omac-theme.conf" "$(<"$gconf")"
contains "ghostty includes font conf"  "omac-font.conf"  "$(<"$gconf")"
contains "vscode editor font"   '"editor.fontFamily": "Hack Nerd Font"'              "$(<"$vscode")"
contains "vscode terminal font" '"terminal.integrated.fontFamily": "Hack Nerd Font"' "$(<"$vscode")"
contains "vscode editor size"   '"editor.fontSize": 15'                              "$(<"$vscode")"
contains "ghostty live-reloaded via SIGUSR2" "-USR2 101" "$(<"$KILL_LOG")"

cfg="$(<"$OMAC_CONFIG/config.zsh")"
contains "font persisted"          'OMAC_ACTIVE_FONT="hack"'      "$cfg"
contains "size persisted"          'OMAC_ACTIVE_FONT_SIZE="15"'   "$cfg"
contains "theme selection preserved" 'OMAC_ACTIVE_THEME="nord"'   "$cfg"

contains "current reports font+size" "hack (15)" "$(zsh "$O" font current)"

# Passthrough: any family string, keeping the persisted size.
zsh "$O" font set "Comic Code" >/dev/null 2>&1
check "passthrough set exits 0" "0" "$?"
contains "passthrough family verbatim" 'font-family = "Comic Code"' "$(<"$fconf")"
contains "passthrough keeps size"      "font-size = 15"             "$(<"$fconf")"

# A non-integer size is rejected.
zsh "$O" font set hack abc >/dev/null 2>&1
check "invalid size exits 1" "1" "$?"

# Re-set updates in place — no duplicate persisted key.
zsh "$O" font set fira-code >/dev/null 2>&1
check "single font line after re-set" "1" "$(grep -c 'OMAC_ACTIVE_FONT=' "$OMAC_CONFIG/config.zsh")"

finish
