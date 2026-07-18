# Canonical omac locations. Every value honors an env override for testing.
: ${OMAC_HOME:="${0:A:h:h}"}
: ${OMAC_CONFIG:="${XDG_CONFIG_HOME:-$HOME/.config}/omac"}
: ${OMAC_STATE:="${XDG_STATE_HOME:-$HOME/.local/state}/omac"}
: ${OMAC_MIGRATIONS_STATE:="$OMAC_STATE/migrations"}
: ${OMAC_PROFILE:="$HOME/.zprofile"}
: ${OMAC_ZSHRC:="$HOME/.zshrc"}     # interactive rc files the shell module wires
: ${OMAC_BASHRC:="$HOME/.bashrc"}   # (and uninstall un-wires) — overridable for tests
: ${OMAC_GITCONFIG:="$HOME/.gitconfig"}  # wired with an [include] of shell/gitconfig
: ${OMAC_CURRENT:="$OMAC_CONFIG/current"}
: ${OMAC_THEMES:="$OMAC_HOME/themes"}
: ${OMAC_TEMPLATES:="$OMAC_HOME/templates"}
: ${OMAC_NVIM:="$OMAC_HOME/nvim"}   # omac-owned LazyVim plugin specs (extras + DX)
: ${OMAC_DEFAULT_THEME:="catppuccin"}
: ${OMAC_ACTIVE_THEME:=""}
: ${OMAC_ACTIVE_WALLPAPER:=""}        # persisted cycle pointer; empty = theme default (01-)
: ${OMAC_FONTS:="$OMAC_HOME/fonts"}   # bundled font registry (one dir per font)
: ${OMAC_DEFAULT_FONT:="jetbrains-mono"}
: ${OMAC_ACTIVE_FONT:=""}             # persisted in config.zsh alongside the theme
: ${OMAC_ACTIVE_FONT_SIZE:=""}        # empty = leave each app's own default size
: ${OMAC_APPSUPPORT:="$HOME/Library/Application Support"}  # VS Code/Cursor settings root (NOT XDG on macOS)
: ${OMAC_SOFTWARE:="$OMAC_HOME/software"}
: ${OMAC_SHELL:="$OMAC_HOME/shell"}
: ${OMAC_WM:="$OMAC_HOME/wm"}
# wm hotkeys helper: SkyLight shim compiled at install time (macOS 26+ ignores
# the symbolichotkeys plist, so the live WindowServer table must be set directly).
: ${OMAC_HOTKEYS_SRC:="$OMAC_WM/hotkeys/omac-hotkeys.swift"}
: ${OMAC_HOTKEYS_BIN:="$OMAC_STATE/bin/omac-hotkeys"}
: ${OMAC_SWIFTC:="swiftc"}   # compiler seam so tests can stub it
# services: the default dev stack (postgres + redis via docker/colima).
: ${OMAC_SERVICES_SRC:="$OMAC_HOME/services"}          # read-only repo source
: ${OMAC_SERVICES_CONFIG:="$OMAC_CONFIG/services"}     # deployed, user-editable
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
