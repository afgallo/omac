#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/software_stubs.zsh"

# Minimal fake OMAC_HOME (symlinked lib/bin/cmd) so the dispatcher runs.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"

# Fixture manifests.
export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
print -r -- 'node@lts'        > "$OMAC_SOFTWARE/runtimes.manifest"

_stub_setup

# bare usage
bare="$(zsh "$fake/bin/omac" software)"
contains "bare prints usage"        "Usage" "$bare"
contains "bare lists shell group"   "shell" "$bare"

# unknown subcommand → nonzero
zsh "$fake/bin/omac" software bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

# install one group
zsh "$fake/bin/omac" software install shell >/dev/null 2>&1
check "install shell exits 0" "0" "$?"
contains "install shell ran brew bundle" "shell.Brewfile" "$(<"$BREW_LOG")"

# unknown group → nonzero + lists valid groups
badout="$(zsh "$fake/bin/omac" software install nope 2>&1)"
zsh "$fake/bin/omac" software install nope >/dev/null 2>&1
check "install unknown group exits 1" "1" "$?"
contains "unknown group lists valid" "shell" "$badout"

# install all
zsh "$fake/bin/omac" software install >/dev/null 2>&1
check "install all exits 0" "0" "$?"

# list
listout="$(zsh "$fake/bin/omac" software list)"
contains "list shows shell"     "shell"     "$listout"
contains "list shows runtimes"  "runtimes"  "$listout"
contains "list shows a status"  "satisfied" "$listout"
finish
