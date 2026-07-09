# help: switch the mono font across the terminal (and its TUIs) and editors
source "$OMAC_HOME/lib/font.zsh"
print -r -- "omac font — switch the mono font everywhere"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac font set <name> [size]   switch font (bundled slug or any family)"
print -r -- "  omac font list                list bundled fonts (● current)"
print -r -- "  omac font current             print the active font"
print -r -- "  omac font reload              re-apply the current font"
print -r -- ""
print -r -- "Applies to: Ghostty (and every terminal TUI it hosts) + VS Code/Cursor."
cur="$(omac::font::resolve_family "$(omac::font::current)")"
sz="$(omac::font::active_size)"
print -r -- ""
print -r -- "Current: $cur${sz:+ ${sz}pt}"
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
