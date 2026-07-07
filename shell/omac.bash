# omac bash interactive config. Sourced from ~/.bashrc via an omac managed block.
# macOS is zsh-first; this keeps bash a first-class fallback with the same tools
# and aliases. Every integration is guarded, so it is safe before software install.

# This file's own directory, so we can load the shared fragment beside it.
OMAC_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- History ----------------------------------------------------------------
HISTFILE="${HISTFILE:-$HOME/.bash_history}"
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
# Flush each command to the history file immediately (shared across shells).
PROMPT_COMMAND="history -a;${PROMPT_COMMAND:+ $PROMPT_COMMAND}"

# --- Shell options ----------------------------------------------------------
shopt -s autocd 2>/dev/null          # `foo/` -> `cd foo/` (bash 4+)
shopt -s cdspell dirspell 2>/dev/null
shopt -s globstar 2>/dev/null        # ** recursive glob
shopt -s checkwinsize
shopt -s nocaseglob

# --- Completion -------------------------------------------------------------
if ! shopt -oq posix; then
  if [ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]; then
    source /opt/homebrew/etc/profile.d/bash_completion.sh
  elif [ -r /usr/local/etc/profile.d/bash_completion.sh ]; then
    source /usr/local/etc/profile.d/bash_completion.sh
  fi
fi

# --- Shared aliases & environment -------------------------------------------
source "$OMAC_SHELL_DIR/shared.sh"

# --- Tool integrations (all guarded) ----------------------------------------
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init bash --cmd cd)"   # cd = z
command -v mise     >/dev/null 2>&1 && eval "$(mise activate bash)"

if command -v fzf >/dev/null 2>&1; then
  # fzf 0.48+ ships shell integration via `fzf --bash` (key bindings + completion).
  eval "$(fzf --bash 2>/dev/null)"
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
  command -v fd >/dev/null 2>&1 && \
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
fi
