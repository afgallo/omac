# help: print the active theme name
source "$OMAC_HOME/lib/theme.zsh"
omac::theme::current || { omac::warn "no active theme"; return 1; }
