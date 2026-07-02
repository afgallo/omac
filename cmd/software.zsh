# help: install curated software groups (brew + mise)
source "$OMAC_HOME/lib/software.zsh"
print -r -- "omac software — install curated software"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac software install [group]   install all groups, or one"
print -r -- "  omac software list              list groups and their status"
print -r -- ""
print -r -- "Groups:"
local g
for g in $(omac::software::groups); do
  print -r -- "  $g"
done
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
