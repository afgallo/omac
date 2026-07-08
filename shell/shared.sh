# omac shared shell config — aliases and environment common to zsh and bash.
# Sourced by shell/omac.zsh and shell/omac.bash. Keep this POSIX-compatible:
# no zsh/bash-only syntax, no arrays. Every tool integration is guarded so the
# file is safe to source before `omac software install` has run.

# --- Editor -----------------------------------------------------------------
if command -v nvim >/dev/null 2>&1; then
  export EDITOR="nvim"
  export VISUAL="nvim"
fi

# --- eza (modern ls) --------------------------------------------------------
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lah --group-directories-first --icons=auto --git'
  alias la='eza -a  --group-directories-first --icons=auto'
  alias lt='eza --tree --level=2 --icons=auto'
fi

# --- bat (modern cat + pager) ----------------------------------------------
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  export BAT_STYLE="plain"
  # Colorize man pages through bat.
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

# --- fd / ripgrep (modern find / grep) -------------------------------------
command -v fd >/dev/null 2>&1 && alias find='fd'
command -v rg >/dev/null 2>&1 && alias grep='rg'

# --- nvim -------------------------------------------------------------------
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
  alias vi='nvim'
fi

# --- TUIs -------------------------------------------------------------------
command -v lazygit    >/dev/null 2>&1 && alias lg='lazygit'
command -v lazydocker >/dev/null 2>&1 && alias lzd='lazydocker'
command -v htop       >/dev/null 2>&1 && alias top='htop'

# --- git shortcuts ----------------------------------------------------------
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gca='git commit --amend'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# --- navigation & safety ----------------------------------------------------
alias mkdir='mkdir -p'
alias df='df -h'
alias du='du -h'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias reload='exec "$SHELL" -l'

# --- omac -------------------------------------------------------------------
command -v omac >/dev/null 2>&1 && alias ot='omac theme set'
