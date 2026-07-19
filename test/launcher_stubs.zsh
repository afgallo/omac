# Shared launcher test stubs: fake system binaries on PATH that log their args.
# Call _launcher_stub_setup AFTER exporting OMAC_* env. Exposes DEFAULTS_LOG,
# OPEN_LOG, PGREP_LOG, ACTIVATE_LOG, NPM_LOG. The `defaults` stub echoes
# $DEFAULTS_READ_OUT on `defaults read …` so tests can drive the hotkey-state
# read path. The `npm` stub logs its args and, on `npm install`, creates a
# node_modules/@raycast marker so palette_deps_installed flips to true. The
# activateSettings stub is invoked by absolute path, so it is exposed via the
# OMAC_ACTIVATE_SETTINGS seam rather than PATH.
_launcher_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export DEFAULTS_LOG="$(mktemp)" OPEN_LOG="$(mktemp)" \
         PGREP_LOG="$(mktemp)" ACTIVATE_LOG="$(mktemp)" NPM_LOG="$(mktemp)"
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
  # npm runs from within the palette dir (cd $OMAC_PALETTE_SRC && npm install),
  # so `npm install` marks deps installed by creating the sentinel in $PWD.
  cat > "$dir/npm" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$NPM_LOG"
[[ "$1" == install ]] && mkdir -p "$PWD/node_modules/@raycast"
exit 0
SH
  chmod +x "$dir/npm"
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

# Create a fake palette source tree at $1 (a package.json is all
# palette_present checks). Returns the path for convenience.
_launcher_palette_fixture() {
  local src="$1"
  mkdir -p "$src"
  print -r -- '{ "name": "omac" }' > "$src/package.json"
  print -r -- "$src"
}
