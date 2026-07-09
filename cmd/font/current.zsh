# help: print the active font (name + size)
source "$OMAC_HOME/lib/font.zsh"
name="$(omac::font::current)" || { omac::warn "no active font"; return 1; }
sz="$(omac::font::active_size)"
print -r -- "$name${sz:+ ($sz)}"
