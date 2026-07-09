# help: list bundled fonts (● current)
source "$OMAC_HOME/lib/font.zsh"
cur="$(omac::font::current)" || cur=""
for f in $(omac::font::list_names); do
  mark=" "; [[ "$f" == "$cur" ]] && mark="●"
  fam="$(omac::font::resolve_family "$f")"
  print -r -- "$mark $f — $fam"
done
return 0
