# Canonical omac locations. Every value honors an env override for testing.
: ${OMAC_HOME:="${0:A:h:h}"}
: ${OMAC_CONFIG:="${XDG_CONFIG_HOME:-$HOME/.config}/omac"}
: ${OMAC_STATE:="${XDG_STATE_HOME:-$HOME/.local/state}/omac"}
: ${OMAC_MIGRATIONS_STATE:="$OMAC_STATE/migrations"}
: ${OMAC_PROFILE:="$HOME/.zprofile"}
: ${OMAC_CURRENT:="$OMAC_CONFIG/current"}
: ${OMAC_THEMES:="$OMAC_HOME/themes"}
: ${OMAC_TEMPLATES:="$OMAC_HOME/templates"}

omac::prefix() {
  if [[ -n "${OMAC_PREFIX:-}" ]]; then
    print -r -- "$OMAC_PREFIX"
  elif command -v brew >/dev/null 2>&1; then
    brew --prefix
  else
    print -r -- "/opt/homebrew"
  fi
}
