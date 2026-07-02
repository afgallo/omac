# help: show this help
print -r -- "omac — Omarchy-style desktop for macOS"
print -r -- ""
print -r -- "Usage: omac <command> [args]"
print -r -- ""
print -r -- "Commands:"
local f name desc
for f in "$OMAC_HOME"/cmd/*.zsh(N); do
  name="${f:t:r}"
  [[ "$name" == _* ]] && continue          # skip private/test commands
  desc="$(grep -m1 '^# help:' "$f" 2>/dev/null | sed 's/^# help: //')"
  printf "  %-10s %s\n" "$name" "$desc"
done
