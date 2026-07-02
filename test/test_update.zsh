#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

# Build a minimal, .git-free OMAC_HOME so `update` skips git pull and brew bundle.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"
mkdir -p "$fake/migrations"
cp "$ROOT/migrations/"*.zsh "$fake/migrations/"

export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_STATE="$(mktemp -d)"
export OMAC_MIGRATIONS_STATE="$OMAC_STATE/migrations"

out="$(zsh "$fake/bin/omac" update 2>&1)"
check "update exits 0" "0" "$?"
contains "update reports completion" "update complete" "$out"
check "update ran migrations" "1" "$(ls "$OMAC_MIGRATIONS_STATE" | grep -c example)"
finish
