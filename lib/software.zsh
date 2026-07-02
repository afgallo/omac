# The software engine: install Homebrew packages (per-group Brewfiles) and mise
# runtimes (runtimes.manifest). Sourced by cmd/software/* and cmd/update.zsh so
# all package logic lives in exactly one place.

# Print all group names: each $OMAC_SOFTWARE/groups/<name>.Brewfile basename,
# then the special `runtimes` group (driven by runtimes.manifest, not a Brewfile).
omac::software::groups() {
  setopt local_options null_glob
  local f
  for f in "$OMAC_SOFTWARE"/groups/*.Brewfile; do
    print -r -- "${f:t:r}"
  done
  print -r -- "runtimes"
}

# Print the absolute Brewfile path for a group (no existence guarantee).
omac::software::group_file() {   # <group>
  print -r -- "$OMAC_SOFTWARE/groups/$1.Brewfile"
}

# Return 0 if <group> is a known group.
omac::software::is_group() {     # <group>
  local g
  for g in $(omac::software::groups); do
    [[ "$g" == "$1" ]] && return 0
  done
  return 1
}
