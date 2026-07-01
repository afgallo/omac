# help: update omac (git pull, brew bundle, run migrations)
source "$OMAC_HOME/lib/migrate.zsh"

if command -v git >/dev/null 2>&1 && [[ -d "$OMAC_HOME/.git" ]]; then
  omac::info "pulling latest omac"
  git -C "$OMAC_HOME" pull --ff-only || omac::warn "git pull skipped/failed; continuing"
fi

if [[ -f "$OMAC_HOME/Brewfile" ]] && command -v brew >/dev/null 2>&1; then
  omac::info "running brew bundle"
  brew bundle --file="$OMAC_HOME/Brewfile" || omac::warn "brew bundle had issues; continuing"
fi

omac::migrate || return 1
omac::ok "update complete"
