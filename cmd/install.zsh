# help: install or repair the omac CLI, shell integration, and base config
typeset prefix bindir
prefix="$(omac::prefix)"
bindir="$prefix/bin"
mkdir -p "$bindir" "$OMAC_CONFIG" "$OMAC_STATE"

# Baseline migrations on first install: stamp every existing migration as already
# applied so a fresh machine never replays historical migrations (mined from
# omarchy's preflight/migrations.sh). Guarded on the ledger's ABSENCE because
# `install` doubles as the repair command — re-running must never mark a genuinely
# pending migration. New migrations arrive later via `omac update`.
if [[ ! -d "$OMAC_MIGRATIONS_STATE" ]]; then
  mkdir -p "$OMAC_MIGRATIONS_STATE"
  typeset m
  for m in "$OMAC_HOME"/migrations/*.zsh(N); do
    : > "$OMAC_MIGRATIONS_STATE/${m:t:r}"
  done
  omac::ok "baselined existing migrations as applied"
fi

ln -sf "$OMAC_HOME/bin/omac" "$bindir/omac"
omac::ok "linked omac -> $bindir/omac"

# Shell integration: ensure brew (and thus omac) is on PATH in new login shells.
omac::ensure_block "$OMAC_PROFILE" 'eval "$('"$prefix"'/bin/brew shellenv)"'
omac::ok "ensured shell integration in $OMAC_PROFILE"

# Seed user config from defaults (never clobber existing).
if [[ -d "$OMAC_HOME/default" ]]; then
  typeset f dest
  for f in "$OMAC_HOME"/default/*(N); do
    dest="$OMAC_CONFIG/${f:t}"
    if [[ -e "$dest" ]]; then
      omac::log "exists, skipping: ${f:t}"
    else
      cp -R "$f" "$dest"
      omac::ok "seeded ${f:t}"
    fi
  done
fi
omac::ok "install complete"
