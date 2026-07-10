# help: configure the desktop (AeroSpace + JankyBorders) and apply macOS tweaks
source "$OMAC_HOME/lib/wm.zsh"
print -r -- "omac wm — configure the keyboard-driven desktop"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac wm install   deploy config, apply tweaks, guided first-run"
print -r -- "  omac wm reload    reload AeroSpace + borders config"
print -r -- "  omac wm status    show which components are deployed"
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
