#!/usr/bin/env zsh
# Resolve every brew/cask/tap token in software/groups/*.Brewfile against a REAL
# Homebrew, type-aware: `brew "x"` must be a formula, `cask "x"` must be a cask.
# This is the layer-1 "manifest validation" that catches wrong tokens (a cask
# declared as a formula, a delisted app) without booting a pristine Mac.
#
# Requires a real `brew` and network. Skips cleanly (exit 0) when brew is absent
# so it never blocks contributors who don't have Homebrew installed. CI runs it
# on a macOS runner where brew is present. Not part of the offline `test/run.zsh`
# unit suite (which is stubbed and hermetic) — invoke it directly or via CI.
emulate -L zsh
setopt extended_glob no_nomatch
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_REQUIRE_TAP_TRUST=1

ROOT="${0:A:h:h}"
GROUPS="$ROOT/software/groups"

if ! command -v brew >/dev/null 2>&1; then
  print -r -- "SKIP: brew not found; cannot validate manifests"
  exit 0
fi

# Parse: collect "kw|token|file:line" for every brew/cask/tap declaration.
typeset -a entries
local f line body kw tok
for f in "$GROUPS"/*.Brewfile; do
  local -i n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    (( n++ ))
    body="${line%%\#*}"                # strip trailing comment
    [[ "$body" == *[![:space:]]* ]] || continue
    if [[ "$body" == (#b)[[:space:]]#(brew|cask|tap)[[:space:]]##\"([^\"]##)\"* ]]; then
      kw="$match[1]"; tok="$match[2]"
      entries+=("$kw|$tok|${f:t}:$n")
    fi
  done < "$f"
done

# Add every declared tap first so tap-qualified tokens can resolve (idempotent).
local e rest where
for e in $entries; do
  [[ "${e%%|*}" == tap ]] || continue
  rest="${e#*|}"; tok="${rest%%|*}"
  brew tap "$tok" >/dev/null 2>&1
done

# Resolve each token, type-aware. Collect all failures before reporting.
typeset -a fails
for e in $entries; do
  kw="${e%%|*}"; rest="${e#*|}"; tok="${rest%%|*}"; where="${rest#*|}"
  case "$kw" in
    brew) brew info --formula "$tok" >/dev/null 2>&1 \
            || fails+=("$where  brew \"$tok\" — not a formula (wrong token, or it's a cask?)") ;;
    cask) brew info --cask "$tok" >/dev/null 2>&1 \
            || fails+=("$where  cask \"$tok\" — not a cask (wrong token, or delisted?)") ;;
    tap)  brew tap-info "$tok" 2>/dev/null | grep -q "Installed" \
            || fails+=("$where  tap \"$tok\" — could not be tapped") ;;
  esac
done

if (( ${#fails} )); then
  print -r -- "Manifest validation FAILED (${#fails} of ${#entries} entries):"
  for e in $fails; print -r -- "  ✗ $e"
  exit 1
fi
print -r -- "Manifest validation OK: ${#entries} entries resolved"
exit 0
