# Shared theme test stubs: fake system binaries on PATH that log their args.
# Call _theme_stub_setup AFTER exporting OMAC_*/XDG_CONFIG_HOME. Exposes one
# <NAME>_LOG per binary (uppercased): OSASCRIPT_LOG, CODE_LOG, CURSOR_LOG,
# SKETCHYBAR_LOG, DEFAULTS_LOG, OPEN_LOG.
_theme_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export OSASCRIPT_LOG="$(mktemp)" CODE_LOG="$(mktemp)" CURSOR_LOG="$(mktemp)" \
         SKETCHYBAR_LOG="$(mktemp)" DEFAULTS_LOG="$(mktemp)" OPEN_LOG="$(mktemp)"
  local name var
  for name in osascript code cursor sketchybar defaults open; do
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
