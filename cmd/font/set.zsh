# help: switch the font — omac font set <name> [size]
# kind: pick
# arg: name from "omac font list"
# icon: text
source "$OMAC_HOME/lib/font.zsh"
if [[ -z "${1:-}" ]]; then
  omac::error "usage: omac font set <name> [size]"
  omac::font::list_names
  return 1
fi
omac::font::set "$1" "${2:-}"
