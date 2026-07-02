# Minimal zsh assertion helper. Source from each test file.
typeset -gi PASS=0 FAIL=0

check() {        # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    print -r -- "ok   - $1"; (( PASS++ ))
  else
    print -r -- "NOT OK - $1"
    print -r -- "    expected: [$2]"
    print -r -- "    actual:   [$3]"
    (( FAIL++ ))
  fi
}

contains() {     # contains <description> <needle> <haystack>
  if [[ "$3" == *"$2"* ]]; then
    print -r -- "ok   - $1"; (( PASS++ ))
  else
    print -r -- "NOT OK - $1 (missing substring: [$2])"; (( FAIL++ ))
  fi
}

finish() {
  print -r -- "--- $PASS passed, $FAIL failed ---"
  (( FAIL == 0 ))
}
