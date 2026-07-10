#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/wm_stubs.zsh"

# Minimal fake OMAC_HOME (symlinked lib/bin/cmd) so the dispatcher runs.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"

# Fixture wm source tree.
export OMAC_WM="$(mktemp -d)/wm"
mkdir -p "$OMAC_WM/aerospace" "$OMAC_WM/borders"
print -r -- "start-at-login = true"          > "$OMAC_WM/aerospace/aerospace.toml"
print -r -- 'source colors.sh'               > "$OMAC_WM/borders/bordersrc"
print -r -- 'export ACTIVE_COLOR=0x0'        > "$OMAC_WM/borders/colors.sh"
print -r -- "NSGlobalDomain KeyRepeat int 2" > "$OMAC_WM/tweaks.conf"

_wm_stub_setup

# bare usage
bare="$(zsh "$fake/bin/omac" wm)"
contains "bare prints usage"          "Usage"   "$bare"
contains "bare mentions install"      "install" "$bare"

# unknown subcommand -> nonzero
zsh "$fake/bin/omac" wm bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

# install
zsh "$fake/bin/omac" wm install >/dev/null 2>&1
check "install exits 0" "0" "$?"
present="$([[ -f "$XDG_CONFIG_HOME/aerospace/aerospace.toml" ]] && print yes || print no)"
check "cli install deployed aerospace" "yes" "$present"

# reload
zsh "$fake/bin/omac" wm reload >/dev/null 2>&1
check "reload exits 0" "0" "$?"
contains "cli reload hit aerospace" "reload-config" "$(<"$AEROSPACE_LOG")"

# status
listout="$(zsh "$fake/bin/omac" wm status)"
contains "status shows aerospace" "aerospace" "$listout"
contains "status shows borders"   "borders"   "$listout"
finish
