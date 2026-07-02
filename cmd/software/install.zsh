# help: install software groups (all, or one named group)
source "$OMAC_HOME/lib/software.zsh"
local group="${1:-}"
if [[ -z "$group" ]]; then
  omac::software::install_all
  return $?
fi
if ! omac::software::is_group "$group"; then
  omac::error "no such group: $group"
  omac::info "valid groups: $(omac::software::groups | tr '\n' ' ')"
  return 1
fi
omac::software::install_group "$group"
