# help: configure the interactive shell (zsh/bash aliases, tools, Starship prompt)
source "$OMAC_HOME/lib/shell.zsh"
print -r -- "omac shell — configure the interactive shell"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac shell install   wire ~/.zshrc + ~/.bashrc, seed Starship, paint palette"
print -r -- "  omac shell status    show which shells are wired"
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
