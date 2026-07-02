# Shared wm test stubs: fake system binaries on PATH that log their args.
# Call _wm_stub_setup AFTER exporting OMAC_*/XDG_CONFIG_HOME. Exposes one
# <NAME>_LOG per binary (uppercased): DEFAULTS_LOG, HIDUTIL_LOG, OPEN_LOG,
# BREW_LOG, AEROSPACE_LOG, SKETCHYBAR_LOG.
_wm_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export DEFAULTS_LOG="$(mktemp)" HIDUTIL_LOG="$(mktemp)" OPEN_LOG="$(mktemp)" \
         BREW_LOG="$(mktemp)" AEROSPACE_LOG="$(mktemp)" SKETCHYBAR_LOG="$(mktemp)"
  local name var
  for name in defaults hidutil open brew aerospace sketchybar; do
    var="${(U)name}_LOG"
    cat > "$dir/$name" <<SH
#!/usr/bin/env zsh
print -r -- "\$*" >> "\$$var"
exit 0
SH
    chmod +x "$dir/$name"
  done
  export PATH="$dir:$PATH"
}
