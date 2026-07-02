# help: list bundled themes (● current, ☾ light)
source "$OMAC_HOME/lib/theme.zsh"
cur="$(omac::theme::current 2>/dev/null)" || cur=""
for t in $(omac::theme::list_names); do
  mark=" "; [[ "$t" == "$cur" ]] && mark="●"
  tag="";  omac::theme::is_light "$t" && tag=" ☾"
  print -r -- "$mark $t$tag"
done
return 0
