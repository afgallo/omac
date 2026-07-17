# Shared wm test stubs: fake system binaries on PATH that log their args.
# Call _wm_stub_setup AFTER exporting OMAC_*/XDG_CONFIG_HOME. Exposes one
# <NAME>_LOG per binary (uppercased): DEFAULTS_LOG, HIDUTIL_LOG, OPEN_LOG,
# BREW_LOG, AEROSPACE_LOG, BORDERS_LOG, LAUNCHCTL_LOG, ACTIVATE_LOG. Also
# redirects the Caps->Escape LaunchAgent into a temp dir (OMAC_LAUNCHAGENTS) so
# tests never touch the real ~/Library/LaunchAgents. The activateSettings stub is
# invoked by absolute path, so it is exposed via the OMAC_ACTIVATE_SETTINGS seam
# rather than PATH — otherwise the real private-framework binary would run and
# mutate the host's symbolic-hotkey settings.
_wm_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export OMAC_LAUNCHAGENTS="$dir/LaunchAgents"
  export DEFAULTS_LOG="$(mktemp)" HIDUTIL_LOG="$(mktemp)" OPEN_LOG="$(mktemp)" \
         BREW_LOG="$(mktemp)" AEROSPACE_LOG="$(mktemp)" BORDERS_LOG="$(mktemp)" \
         LAUNCHCTL_LOG="$(mktemp)" ACTIVATE_LOG="$(mktemp)"
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
}
