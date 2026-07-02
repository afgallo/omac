# help: guide Raycast first-run (free ⌘Space, hand-hold the GUI-only steps)
source "$OMAC_HOME/lib/launcher.zsh"
print -r -- "omac launcher — set up Raycast as the keyboard launcher"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac launcher install   free ⌘Space + guided Raycast first-run"
print -r -- "  omac launcher status    show Raycast install/run state and ⌘Space"
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
