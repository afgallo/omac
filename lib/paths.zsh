# Canonical omac locations. Every value honors an env override for testing.
: ${OMAC_HOME:="${0:A:h:h}"}
: ${OMAC_CONFIG:="${XDG_CONFIG_HOME:-$HOME/.config}/omac"}
: ${OMAC_STATE:="${XDG_STATE_HOME:-$HOME/.local/state}/omac"}
: ${OMAC_MIGRATIONS_STATE:="$OMAC_STATE/migrations"}
: ${OMAC_PROFILE:="$HOME/.zprofile"}
: ${OMAC_CURRENT:="$OMAC_CONFIG/current"}
: ${OMAC_THEMES:="$OMAC_HOME/themes"}
: ${OMAC_TEMPLATES:="$OMAC_HOME/templates"}
: ${OMAC_NVIM:="$OMAC_HOME/nvim"}   # omac-owned LazyVim plugin specs (extras + DX)
: ${OMAC_DEFAULT_THEME:="catppuccin"}
: ${OMAC_ACTIVE_THEME:=""}
: ${OMAC_APPSUPPORT:="$HOME/Library/Application Support"}  # VS Code/Cursor settings root (NOT XDG on macOS)
: ${OMAC_SOFTWARE:="$OMAC_HOME/software"}
: ${OMAC_SHELL:="$OMAC_HOME/shell"}
: ${OMAC_WM:="$OMAC_HOME/wm"}
# launcher: internal seams (not user-facing). Raycast ships no PATH binary, so we
# detect its app bundle; activateSettings is a fixed private-framework binary.
: ${OMAC_RAYCAST_APP:="/Applications/Raycast.app"}
: ${OMAC_ACTIVATE_SETTINGS:="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"}

omac::prefix() {
  if [[ -n "${OMAC_PREFIX:-}" ]]; then
    print -r -- "$OMAC_PREFIX"
  elif command -v brew >/dev/null 2>&1; then
    brew --prefix
  else
    print -r -- "/opt/homebrew"
  fi
}
