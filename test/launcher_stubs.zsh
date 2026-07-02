# Shared launcher test stubs: fake system binaries on PATH that log their args.
# Call _launcher_stub_setup AFTER exporting OMAC_* env. Exposes DEFAULTS_LOG,
# OPEN_LOG, PGREP_LOG, ACTIVATE_LOG. The `defaults` stub echoes $DEFAULTS_READ_OUT
# on `defaults read …` so tests can drive the hotkey-state read path. The
# activateSettings stub is invoked by absolute path, so it is exposed via the
# OMAC_ACTIVATE_SETTINGS seam rather than PATH.
_launcher_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export DEFAULTS_LOG="$(mktemp)" OPEN_LOG="$(mktemp)" \
         PGREP_LOG="$(mktemp)" ACTIVATE_LOG="$(mktemp)"
  local name var
  for name in defaults open pgrep; do
    var="${(U)name}_LOG"
    cat > "$dir/$name" <<SH
#!/usr/bin/env zsh
print -r -- "\$*" >> "\$$var"
[[ "\$1" == read ]] && print -r -- "\${DEFAULTS_READ_OUT:-}"
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
