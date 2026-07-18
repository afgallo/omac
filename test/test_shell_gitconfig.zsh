#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"

# Isolate HOME so OMAC_GITCONFIG (derived from $HOME at source time) points at
# a throwaway dir, never the real ~/.gitconfig.
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"

source "$ROOT/lib/paths.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_SHELL="$(mktemp -d)/shell"
mkdir -p "$OMAC_SHELL"
print -r -- "[alias]" > "$OMAC_SHELL/gitconfig"

source "$ROOT/lib/shell.zsh"

# --- deploy: managed block with an [include] of the repo gitconfig -----------
omac::shell::deploy_gitconfig >/dev/null
check "gitconfig block written" "1" "$(grep -c '>>> omac >>>' "$OMAC_GITCONFIG")"
contains "block includes repo gitconfig" "path = $OMAC_SHELL/gitconfig" "$(<"$OMAC_GITCONFIG")"

# Idempotent: a second deploy does not duplicate the block.
omac::shell::deploy_gitconfig >/dev/null
check "gitconfig block not duplicated" "1" "$(grep -c '>>> omac >>>' "$OMAC_GITCONFIG")"

# Non-destructive: the user's own settings around the block are preserved.
rm -f "$OMAC_GITCONFIG"
print -r -- "[user]
	name = Test User" > "$OMAC_GITCONFIG"
omac::shell::deploy_gitconfig >/dev/null
contains "user settings preserved" "name = Test User" "$(<"$OMAC_GITCONFIG")"
contains "include appended after user settings" "path = $OMAC_SHELL/gitconfig" "$(<"$OMAC_GITCONFIG")"

# --- the shipped aliases actually resolve through the include ----------------
if command -v git >/dev/null 2>&1; then
  print -r -- "	st = status" >> "$OMAC_SHELL/gitconfig"
  check "git resolves st via include" "status" \
    "$(GIT_CONFIG_NOSYSTEM=1 git config --file "$OMAC_GITCONFIG" --includes alias.st)"
fi

# --- status reports the wire -------------------------------------------------
contains "status reports gitconfig wired" ".gitconfig   yes" "$(omac::shell::status)"
rm -f "$OMAC_GITCONFIG"
contains "status reports gitconfig unwired" ".gitconfig   no" "$(omac::shell::status)"

finish
