# help: switch among the bundled themes (terminal, editor, window borders, wallpaper)
source "$OMAC_HOME/lib/theme.zsh"
print -r -- "omac theme — switch the desktop theme"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac theme install       wire apps, pre-install extensions, set default"
print -r -- "  omac theme set <name>    switch to a bundled theme"
print -r -- "  omac theme list          list bundled themes (● current, ☾ light)"
print -r -- "  omac theme current       print the active theme"
print -r -- "  omac theme reload        re-apply the current theme"
if cur="$(omac::theme::current 2>/dev/null)"; then
  print -r -- ""
  print -r -- "Current: $cur"
fi
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
