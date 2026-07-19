# help: list every omac command (add --json for a machine-readable feed)
# hidden: true
source "$OMAC_HOME/lib/registry.zsh"
if [[ "${1:-}" == "--json" ]]; then
  omac::registry::json
else
  omac::registry::help
fi
