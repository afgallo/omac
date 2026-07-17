# Shared test stubs: fake `brew` and `mise` on PATH that log their args to files.
# Call _stub_setup AFTER exporting OMAC_* env. Exposes $BREW_LOG and $MISE_LOG.
_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export BREW_LOG="$(mktemp)" MISE_LOG="$(mktemp)"
  cat > "$dir/brew" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$BREW_LOG"
# A "broken" group fails both the check probe and the install, so install_group's
# fast path can't mistake it for satisfied. Order matters: check this first.
case "$*" in *broken*) exit 1 ;; esac
[[ "$1" == "bundle" && "$2" == "check" ]] && exit "${BREW_CHECK_RC:-0}"
exit 0
SH
  cat > "$dir/mise" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$MISE_LOG"
exit 0
SH
  chmod +x "$dir/brew" "$dir/mise"
  export PATH="$dir:$PATH"
}
