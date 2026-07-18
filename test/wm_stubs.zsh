# Shared wm test stubs: fake system binaries on PATH that log their args.
# Call _wm_stub_setup AFTER exporting OMAC_*/XDG_CONFIG_HOME. Exposes one
# <NAME>_LOG per binary (uppercased): DEFAULTS_LOG, HIDUTIL_LOG, OPEN_LOG,
# BREW_LOG, AEROSPACE_LOG, BORDERS_LOG, LAUNCHCTL_LOG, ACTIVATE_LOG, SWIFTC_LOG,
# HOTKEYS_LOG. Also redirects the Caps->Escape LaunchAgent into a temp dir
# (OMAC_LAUNCHAGENTS) so tests never touch the real ~/Library/LaunchAgents. The
# activateSettings stub is invoked by absolute path, so it is exposed via the
# OMAC_ACTIVATE_SETTINGS seam rather than PATH — otherwise the real
# private-framework binary would run and mutate the host's symbolic-hotkey
# settings. Same idea for the hotkeys helper: OMAC_SWIFTC/SRC/BIN point into the
# temp dir, and the swiftc stub "compiles" by writing a fake omac-hotkeys that
# logs its args to HOTKEYS_LOG — the real one would mutate WindowServer state.
_wm_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export OMAC_LAUNCHAGENTS="$dir/LaunchAgents"
  export DEFAULTS_LOG="$(mktemp)" HIDUTIL_LOG="$(mktemp)" OPEN_LOG="$(mktemp)" \
         BREW_LOG="$(mktemp)" AEROSPACE_LOG="$(mktemp)" BORDERS_LOG="$(mktemp)" \
         LAUNCHCTL_LOG="$(mktemp)" ACTIVATE_LOG="$(mktemp)" \
         SWIFTC_LOG="$(mktemp)" HOTKEYS_LOG="$(mktemp)"
  local name var
  for name in defaults hidutil open brew aerospace borders launchctl; do
    var="${(U)name}_LOG"
    cat > "$dir/$name" <<SH
#!/usr/bin/env zsh
print -r -- "\$*" >> "\$$var"
exit 0
SH
    chmod +x "$dir/$name"
  done
  export PATH="$dir:$PATH"
  local act="$dir/activateSettings"
  cat > "$act" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$ACTIVATE_LOG"
exit 0
SH
  chmod +x "$act"
  export OMAC_ACTIVATE_SETTINGS="$act"
  # Hotkeys helper seams: fake source + compiler; the "compiled" binary logs to
  # HOTKEYS_LOG instead of touching WindowServer.
  export OMAC_HOTKEYS_SRC="$dir/omac-hotkeys.swift"
  export OMAC_HOTKEYS_BIN="$dir/state/bin/omac-hotkeys"
  export OMAC_SWIFTC="$dir/swiftc"
  : > "$OMAC_HOTKEYS_SRC"
  cat > "$OMAC_SWIFTC" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$SWIFTC_LOG"
while (( $# > 0 )) && [[ "$1" != -o ]]; do shift; done
[[ "${1:-}" == -o && -n "${2:-}" ]] || exit 0
mkdir -p "${2:h}"
cat > "$2" <<'BIN'
#!/usr/bin/env zsh
print -r -- "$*" >> "$HOTKEYS_LOG"
BIN
chmod +x "$2"
SH
  chmod +x "$OMAC_SWIFTC"
}
