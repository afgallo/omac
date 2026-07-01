#!/usr/bin/env zsh
emulate -L zsh
cd "${0:A:h}"
typeset -i rc=0
typeset f
for f in test_*.zsh; do
  print -r -- "== $f =="
  zsh "$f" || rc=1
done
exit $rc
