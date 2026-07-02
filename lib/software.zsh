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

# Install one group. `runtimes` uses the mise driver; every other group is a
# plain `brew bundle` over its Brewfile. Returns the underlying command status.
omac::software::install_group() {   # <group>
  local group="$1"
  if [[ "$group" == "runtimes" ]]; then
    omac::software::install_runtimes
    return $?
  fi
  local file; file="$(omac::software::group_file "$group")"
  if [[ ! -f "$file" ]]; then
    omac::error "no such group: $group"
    return 1
  fi
  omac::require_cmd brew || return 1
  omac::info "installing group: $group"
  brew bundle --file="$file"
}

# Ensure mise is present, then apply every runtimes.manifest entry in one
# `mise use -g` call (records the pin and installs it — idempotent).
omac::software::install_runtimes() {
  omac::require_cmd brew || return 1
  if ! command -v mise >/dev/null 2>&1; then
    omac::info "installing mise"
    brew install mise || return 1
  fi
  local manifest="$OMAC_SOFTWARE/runtimes.manifest"
  if [[ ! -f "$manifest" ]]; then
    omac::warn "no runtimes.manifest; skipping runtimes"
    return 0
  fi
  local -a tools
  local line tok
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"          # drop trailing comment
    tok=(${=line})              # word-split; single token per manifest line
    (( ${#tok} )) && tools+=("${tok[1]}")
  done < "$manifest"
  if (( ! ${#tools} )); then
    omac::warn "runtimes.manifest is empty"
    return 0
  fi
  omac::info "installing runtimes: ${tools[*]}"
  mise use -g "${tools[@]}"
}

# Install every group. Continue past a failing group so one bad Brewfile never
# blocks the rest; print a summary; return non-zero if any group failed.
omac::software::install_all() {
  omac::require_cmd brew || return 1
  local -a failed
  local g
  for g in $(omac::software::groups); do
    if ! omac::software::install_group "$g"; then
      failed+=("$g")
      omac::warn "group failed: $g (continuing)"
    fi
  done
  if (( ${#failed} )); then
    omac::error "software: ${#failed} group(s) failed: ${failed[*]}"
    return 1
  fi
  omac::ok "software: all groups installed"
  return 0
}

# Non-mutating status for `list`: prints "satisfied" or "missing".
omac::software::group_status() {   # <group>
  local group="$1"
  if [[ "$group" == "runtimes" ]]; then
    command -v mise >/dev/null 2>&1 && print -r -- "satisfied" || print -r -- "missing"
    return 0
  fi
  local file; file="$(omac::software::group_file "$group")"
  if command -v brew >/dev/null 2>&1 && brew bundle check --file="$file" >/dev/null 2>&1; then
    print -r -- "satisfied"
  else
    print -r -- "missing"
  fi
}
