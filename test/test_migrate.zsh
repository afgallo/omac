#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_STATE="$(mktemp -d)"
export OMAC_MIGRATIONS_STATE="$OMAC_STATE/migrations"

source "$ROOT/lib/paths.zsh"
source "$ROOT/lib/common.zsh"
source "$ROOT/lib/migrate.zsh"

omac::migrate >/dev/null 2>&1
check "marker written after first run" "1" "$(ls "$OMAC_MIGRATIONS_STATE" | grep -c example)"
omac::migrate >/dev/null 2>&1
check "second run exits 0" "0" "$?"
check "marker still present" "1" "$(ls "$OMAC_MIGRATIONS_STATE" | grep -c example)"

# a failed migration can be skipped (separate ledger) without blocking the run
skip_out="$(
  fake="$(mktemp -d)"; ln -s "$ROOT/lib" "$fake/lib"; mkdir -p "$fake/migrations"
  print -r -- 'exit 1' > "$fake/migrations/29990101000000-boom.zsh"
  s="$(mktemp -d)"
  OMAC_HOME="$fake" OMAC_MIGRATIONS_STATE="$s/migrations"
  OMAC_YES=1 omac::migrate >/dev/null 2>&1
  print -r -- "$?:$(ls "$OMAC_MIGRATIONS_STATE/skipped" 2>/dev/null | grep -c boom)"
)"
check "skipping a failed migration exits 0" "0" "${skip_out%%:*}"
check "the skip is recorded in its own ledger" "1" "${skip_out##*:}"
finish
