# The command registry: the single source of truth for what omac commands exist
# and what they mean. Walks cmd/**, parses each script's header tags into a
# normalized model, and renders it for humans (omac help / omac commands) and
# machines (omac commands --json → the Raycast palette's feed). Both the CLI and
# the launcher read from here, so the two surfaces can never drift.
#
# A command script may carry these header tags (one per line, near the top; only
# `# help:` is required — the rest degrade to sensible inference):
#
#   # help:   <one-line description>       drives `omac help` and the palette subtitle
#   # group:  <display group>             default: nested → Title-cased module; flat → General
#   # kind:   read|pick|apply|mutate      default: read for status/list/current/…; else mutate
#   # arg:    <name> from "<command>"     a pick's choices come from <command>'s stdout
#   # icon:   <name>                      optional palette icon hint
#   # title:  <short title>               default: Title-cased last path token
#   # hidden: true                        omit from help, commands, and the palette
#
# kinds — the UX contract the Raycast palette honors:
#   read   — no side effects; run inline, show output.
#   pick   — needs one choice from `# arg`; palette shows a dropdown, then runs.
#   apply  — non-interactive mutation; run inline, confirm with a toast.
#   mutate — interactive / privileged / long; palette opens it in Ghostty (a real TTY).
#
# The scanned model lives in eight parallel arrays (OMAC_REG_*), indexed 1..N.
# Parallel arrays (not a packed string) so empty fields — a read command has no
# arg or icon — keep their slot instead of collapsing on a split.

# Read one `# <tag>: value` header line from a command script. Empty + return 1
# if absent. First match wins, so the header takes precedence over body text.
omac::registry::tag() {          # <file> <tag>
  local file="$1" tag="$2" line
  line="$(grep -m1 "^# ${tag}:" "$file" 2>/dev/null)" || return 1
  [[ -n "$line" ]] || return 1
  line="${line#\# ${tag}:}"      # strip the "# tag:" prefix
  line="${line# }"              # strip the single leading space
  print -r -- "$line"
}

# Default kind for a command whose header omits `# kind:` — keyed on the last
# path token. Read-only verbs are safe inline; everything else defaults to a real
# terminal (mutate), the fail-safe choice when a command's needs are unknown.
omac::registry::infer_kind() {   # <last-token>
  case "$1" in
    status|list|current|path|version|doctor|help|commands) print -r -- read ;;
    *)                                                      print -r -- mutate ;;
  esac
}

# Title-case a single path token for display (set → Set, boot → Boot).
omac::registry::titlecase() {    # <word>
  print -r -- "${(C)1}"
}

# Emit one leaf command into the OMAC_REG_* arrays. <sub> empty ⇒ a flat solo
# command (cmd == module, default group General); otherwise a nested subcommand
# (cmd == "module sub", default group Title-cased module). Hidden leaves drop out.
omac::registry::_emit() {        # <file> <module> <sub>
  local f="$1" module="$2" sub="$3"
  [[ "$(omac::registry::tag "$f" hidden)" == true ]] && return 0
  local cmd last group kind title desc icon arg argname argsrc
  if [[ -n "$sub" ]]; then
    cmd="$module $sub"; last="$sub"
    group="$(omac::registry::tag "$f" group)" || group="$(omac::registry::titlecase "$module")"
  else
    cmd="$module"; last="$module"
    group="$(omac::registry::tag "$f" group)" || group="General"
  fi
  desc="$(omac::registry::tag "$f" help)"   || desc=""
  kind="$(omac::registry::tag "$f" kind)"   || kind="$(omac::registry::infer_kind "$last")"
  title="$(omac::registry::tag "$f" title)" || title="$(omac::registry::titlecase "$last")"
  icon="$(omac::registry::tag "$f" icon)"   || icon=""
  # `# arg: <name> from "<command>"` → the pick's dropdown label + source command.
  arg="$(omac::registry::tag "$f" arg)" || arg=""
  argname=""; argsrc=""
  if [[ -n "$arg" ]]; then
    argname="${arg%% from *}"
    argsrc="${arg#* from }"
    argsrc="${argsrc#\"}"; argsrc="${argsrc%\"}"
  fi
  OMAC_REG_CMD+=("$cmd");      OMAC_REG_GROUP+=("$group")
  OMAC_REG_TITLE+=("$title");  OMAC_REG_DESC+=("$desc")
  OMAC_REG_KIND+=("$kind");    OMAC_REG_ARGNAME+=("$argname")
  OMAC_REG_ARGSRC+=("$argsrc"); OMAC_REG_ICON+=("$icon")
}

# Populate the OMAC_REG_* arrays from $OMAC_HOME/cmd. Flat solo commands first
# (cmd/X.zsh with no cmd/X/ dir), then nested leaves (cmd/X/sub.zsh). A parent
# stub (cmd/X.zsh that has a cmd/X/ dir) is a usage/dispatch shell, not an action,
# so it is skipped — its group is represented by its leaves. `_`-prefixed files
# are private/test commands and never surface.
omac::registry::scan() {
  setopt local_options null_glob
  typeset -ga OMAC_REG_CMD OMAC_REG_GROUP OMAC_REG_TITLE OMAC_REG_DESC \
              OMAC_REG_KIND OMAC_REG_ARGNAME OMAC_REG_ARGSRC OMAC_REG_ICON
  OMAC_REG_CMD=(); OMAC_REG_GROUP=(); OMAC_REG_TITLE=(); OMAC_REG_DESC=()
  OMAC_REG_KIND=(); OMAC_REG_ARGNAME=(); OMAC_REG_ARGSRC=(); OMAC_REG_ICON=()
  local f base module sub
  for f in "$OMAC_HOME"/cmd/*.zsh; do
    base="${f:t:r}"
    [[ "$base" == _* ]] && continue
    [[ -d "$OMAC_HOME/cmd/$base" ]] && continue   # a group parent stub
    omac::registry::_emit "$f" "$base" ""
  done
  for f in "$OMAC_HOME"/cmd/*/*.zsh; do
    sub="${f:t:r}"
    [[ "$sub" == _* ]] && continue
    module="${f:h:t}"
    omac::registry::_emit "$f" "$module" "$sub"
  done
}

# Human listing, grouped — the body of `omac help` and `omac commands`.
omac::registry::help() {
  omac::registry::scan
  print -r -- "omac — Omarchy-style desktop for macOS"
  print -r -- ""
  print -r -- "Usage: omac <command> [args]"
  print -r -- ""
  local -a groups
  local i g
  for i in {1..${#OMAC_REG_CMD}}; do
    g="${OMAC_REG_GROUP[i]}"
    (( ${groups[(Ie)$g]} )) || groups+=("$g")
  done
  for g in "${groups[@]}"; do
    print -r -- "$g:"
    for i in {1..${#OMAC_REG_CMD}}; do
      [[ "${OMAC_REG_GROUP[i]}" == "$g" ]] || continue
      printf "  %-18s %s\n" "${OMAC_REG_CMD[i]}" "${OMAC_REG_DESC[i]}"
    done
    print -r -- ""
  done
}

# JSON-escape a scalar (backslash first, then quote). Descriptions are plain
# one-liners — no control characters — so quotes and backslashes are enough.
omac::registry::_esc() {         # <string>
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  print -r -- "$s"
}

# Machine-readable feed: a JSON array of leaf commands, one object each. This is
# what the Raycast palette consumes (via `omac commands --json`).
omac::registry::json() {
  omac::registry::scan
  local i first=1
  print -r -- "["
  for i in {1..${#OMAC_REG_CMD}}; do
    (( first )) || print -r -- ","
    first=0
    printf '  {"cmd":"%s","group":"%s","title":"%s","desc":"%s","kind":"%s","argName":"%s","argSource":"%s","icon":"%s"}' \
      "$(omac::registry::_esc "${OMAC_REG_CMD[i]}")" \
      "$(omac::registry::_esc "${OMAC_REG_GROUP[i]}")" \
      "$(omac::registry::_esc "${OMAC_REG_TITLE[i]}")" \
      "$(omac::registry::_esc "${OMAC_REG_DESC[i]}")" \
      "$(omac::registry::_esc "${OMAC_REG_KIND[i]}")" \
      "$(omac::registry::_esc "${OMAC_REG_ARGNAME[i]}")" \
      "$(omac::registry::_esc "${OMAC_REG_ARGSRC[i]}")" \
      "$(omac::registry::_esc "${OMAC_REG_ICON[i]}")"
  done
  print -r -- ""
  print -r -- "]"
}
