# help: list software groups and their status
source "$OMAC_HOME/lib/software.zsh"
# NB: local is `st`, NOT `status` — in zsh `$status` is a read-only alias for `$?`.
local g st
printf "%-12s %s\n" "GROUP" "STATUS"
for g in $(omac::software::groups); do
  st="$(omac::software::group_status "$g")"
  printf "%-12s %s\n" "$g" "$st"
done
