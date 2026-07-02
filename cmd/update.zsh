# help: update omac (git pull, brew bundle, run migrations)
source "$OMAC_HOME/lib/migrate.zsh"

if command -v git >/dev/null 2>&1 && [[ -d "$OMAC_HOME/.git" ]]; then
  omac::info "pulling latest omac"
  git -C "$OMAC_HOME" pull --ff-only || omac::warn "git pull skipped/failed; continuing"
fi

if command -v brew >/dev/null 2>&1; then
  source "$OMAC_HOME/lib/software.zsh"
  omac::info "installing software"
  omac::software::install_all || omac::warn "some software groups had issues; continuing"
fi

omac::migrate || return 1
omac::ok "update complete"
