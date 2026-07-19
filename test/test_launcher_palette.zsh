#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

_launcher_stub_setup
source "$ROOT/lib/launcher.zsh"

# ── presence + deps detection ────────────────────────────────────────────────
export OMAC_PALETTE_SRC="/nonexistent/palette"
omac::launcher::palette_present && r=yes || r=no
check "palette_present is no when source is missing" "no" "$r"

export OMAC_PALETTE_SRC="$(_launcher_palette_fixture "$(mktemp -d)/raycast/omac")"
omac::launcher::palette_present && r=yes || r=no
check "palette_present is yes with a package.json" "yes" "$r"

omac::launcher::palette_deps_installed && r=yes || r=no
check "deps not installed before npm install" "no" "$r"

# ── install: missing source is a non-fatal skip ──────────────────────────────
export OMAC_PALETTE_SRC="/nonexistent/palette"
: > "$NPM_LOG"
out="$(omac::launcher::palette_install 2>&1)"; rc=$?
check "install exits 0 when source is missing" "0" "$rc"
contains "install warns about missing source" "not found" "$out"
check "install runs no npm when source is missing" "" "$(<"$NPM_LOG")"

# ── install: builds deps then guides the import ──────────────────────────────
export OMAC_PALETTE_SRC="$(_launcher_palette_fixture "$(mktemp -d)/raycast/omac")"
: > "$NPM_LOG"
out="$(omac::launcher::palette_install 2>&1)"; rc=$?
check "install exits 0 on the happy path" "0" "$rc"
contains "install runs npm install" "install" "$(<"$NPM_LOG")"
contains "install guides npm run dev" "npm run dev" "$out"
omac::launcher::palette_deps_installed && r=yes || r=no
check "deps installed after npm install" "yes" "$r"

# ── install: deps already present skips npm install ──────────────────────────
: > "$NPM_LOG"
out="$(omac::launcher::palette_install 2>&1)"; rc=$?
check "install exits 0 when deps present" "0" "$rc"
check "install skips npm when deps present" "" "$(<"$NPM_LOG")"

# ── status surfaces palette rows ─────────────────────────────────────────────
export OMAC_RAYCAST_APP="/nonexistent/Raycast.app"
export DEFAULTS_READ_OUT=""
out="$(omac::launcher::status)"
contains "status shows palette source row" "palette source:" "$out"
contains "status shows palette built row"  "palette built:"  "$out"
built_row="$(print -r -- "$out" | grep 'palette built:')"
contains "status reports palette built yes" "yes" "$built_row"

finish
