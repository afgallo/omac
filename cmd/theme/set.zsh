# help: switch to a bundled theme — omac theme set <name>
source "$OMAC_HOME/lib/theme.zsh"
if [[ -z "${1:-}" ]]; then
  omac::error "usage: omac theme set <name>"
  omac::theme::list_names
  return 1
fi
omac::theme::set "$1"
