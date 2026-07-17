# help: cycle the desktop wallpaper within the current theme
source "$OMAC_HOME/lib/wallpaper.zsh"
print -r -- "omac wallpaper — cycle the desktop wallpaper"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac wallpaper next      apply the next background for the current theme (wraps)"
print -r -- "  omac wallpaper list      list the current theme's backgrounds (● current)"
print -r -- "  omac wallpaper current   print the active wallpaper"
if cur="$(omac::wallpaper::current 2>/dev/null)"; then
  print -r -- ""
  print -r -- "Current: $cur"
fi
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
