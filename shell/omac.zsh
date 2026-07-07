# omac zsh interactive config. Sourced from ~/.zshrc via an omac managed block.
# Safe to source when tools are missing — every integration is guarded, so a
# fresh shell never errors, it just wires up whatever `omac software` installed.

# This file's own directory, so we can load the shared fragment beside it.
OMAC_SHELL_DIR="${${(%):-%x}:A:h}"

# --- History ----------------------------------------------------------------
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS HIST_VERIFY EXTENDED_HISTORY

# --- Directories & globbing -------------------------------------------------
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt EXTENDED_GLOB GLOB_DOTS
setopt INTERACTIVE_COMMENTS NO_BEEP

# --- Completion -------------------------------------------------------------
# Put Homebrew's site-functions on fpath before compinit. Hardcode the Apple
# Silicon prefix (omac is arm64-only) to avoid a `brew --prefix` subprocess on
# every shell start.
[[ -d /opt/homebrew/share/zsh/site-functions ]] && \
  fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
# zsh-completions ships extra compdefs; must join fpath before compinit runs.
[[ -d /opt/homebrew/share/zsh-completions ]] && \
  fpath=(/opt/homebrew/share/zsh-completions $fpath)

autoload -Uz compinit
# Rebuild the completion dump at most once a day; otherwise load it cached
# (-C skips the security audit). -i silences the insecure-directory prompt that
# a group-writable Homebrew completions dir would otherwise raise on first run.
_omac_zcd="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -n "$_omac_zcd"(#qNmh+24) ]]; then
  compinit -i
else
  compinit -C -i
fi
unset _omac_zcd

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{blue}%d%f'

# --- Keybindings (emacs) ----------------------------------------------------
bindkey -e
bindkey '^[[A' history-search-backward   # Up:   prefix search
bindkey '^[[B' history-search-forward    # Down: prefix search
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# --- Shared aliases & environment -------------------------------------------
source "$OMAC_SHELL_DIR/shared.sh"

# --- Tool integrations (all guarded) ----------------------------------------
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd cd)"   # cd = z
command -v mise     >/dev/null 2>&1 && eval "$(mise activate zsh)"

if command -v fzf >/dev/null 2>&1; then
  # fzf 0.48+ ships shell integration via `fzf --zsh` (key bindings + completion).
  source <(fzf --zsh) 2>/dev/null
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
  command -v fd >/dev/null 2>&1 && \
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
fi

# --- Interactive plugins (order matters) ------------------------------------
# Lean alternative to a framework: two brew-installed plugins sourced directly.
# Autosuggestions offers a dim, history/completion-based ghost suggestion you
# accept with → (End). It binds ZLE widgets, so it must come before the
# highlighter below.
if [[ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'   # dim grey, theme-agnostic
fi

# syntax-highlighting rewraps every ZLE widget, so it MUST be the last plugin
# sourced — after compinit, fzf, and autosuggestions — or it won't wrap them.
[[ -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
