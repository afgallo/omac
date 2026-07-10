# Shared theme test stubs: fake system binaries on PATH that log their args.
# Call _theme_stub_setup AFTER exporting OMAC_*/XDG_CONFIG_HOME. Exposes one
# <NAME>_LOG per binary (uppercased): OSASCRIPT_LOG, CODE_LOG, CURSOR_LOG,
# BORDERS_LOG, DEFAULTS_LOG, OPEN_LOG, BAT_LOG, GIT_LOG, WALLPAPER_LOG,
# TMUX_LOG, PKILL_LOG, KILL_LOG.
_theme_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export OSASCRIPT_LOG="$(mktemp)" CODE_LOG="$(mktemp)" CURSOR_LOG="$(mktemp)" \
         BORDERS_LOG="$(mktemp)" DEFAULTS_LOG="$(mktemp)" OPEN_LOG="$(mktemp)" \
         BAT_LOG="$(mktemp)" GIT_LOG="$(mktemp)" WALLPAPER_LOG="$(mktemp)" \
         TMUX_LOG="$(mktemp)" PKILL_LOG="$(mktemp)" KILL_LOG="$(mktemp)"
  local name var
  for name in osascript code cursor borders defaults open bat git wallpaper tmux pkill kill; do
    var="${(U)name}_LOG"
    cat > "$dir/$name" <<SH
#!/usr/bin/env zsh
print -r -- "\$*" >> "\$$var"
exit 0
SH
    chmod +x "$dir/$name"
  done
  # Fake process table for omac::signal_app: ghostty as a macOS app
  # bundle (the shape pkill can't match — the regression this guards), nvim as
  # a plain CLI proc, plus noise that must NOT be signalled.
  cat > "$dir/ps" <<'SH'
#!/usr/bin/env zsh
print -r -- "  101 /Applications/Ghostty.app/Contents/MacOS/ghostty"
print -r -- "  303 nvim"
print -r -- "  404 /bin/zsh"
SH
  chmod +x "$dir/ps"
  export PATH="$dir:$PATH"
}
