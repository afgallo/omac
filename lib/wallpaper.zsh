# The wallpaper engine: cycle the desktop background within the current theme.
# Backgrounds live under themes/<name>/backgrounds/ (the theme seam owns them),
# so this module is a thin sibling of lib/theme.zsh — it reuses the theme's
# background listing and low-level image setter, and tracks which one is active
# via the OMAC_ACTIVE_WALLPAPER pointer persisted in config.zsh (empty = "at the
# theme default", i.e. 01-). cmd/wallpaper/* stay thin; all logic lives here,
# namespaced omac::wallpaper::*.
#
# Guarded so unit tests that source wallpaper.zsh in isolation still load.
[[ -f "$OMAC_HOME/lib/theme.zsh" ]] && source "$OMAC_HOME/lib/theme.zsh"

# The current theme's backgrounds as a sorted array (cycle order). Returns 1 when
# there's no active theme or it has no backgrounds; callers decide how to report.
omac::wallpaper::_list() {   # (out: prints one abs path per line)
  local theme; theme="$(omac::theme::current)" || return 1
  omac::theme::backgrounds "$theme"
}

# The active wallpaper's basename for the current theme. The persisted pointer
# wins when it still names one of this theme's backgrounds; otherwise (empty or
# stale — e.g. after a theme switch) the theme default (first in cycle order).
omac::wallpaper::current() {
  local out; out="$(omac::wallpaper::_list)" || return 1
  local -a bgs=("${(f)out}")
  (( ${#bgs} )) || return 1
  local want="${OMAC_ACTIVE_WALLPAPER:-}" f
  if [[ -n "$want" ]]; then
    for f in "${bgs[@]}"; do
      [[ "${f:t}" == "$want" ]] && { print -r -- "$want"; return 0; }
    done
  fi
  print -r -- "${bgs[1]:t}"
}

# Persist the cycle pointer and keep the in-memory value in sync so repeated
# calls within one process (and the tests) advance correctly.
omac::wallpaper::persist() {   # <basename>
  omac::config_set OMAC_ACTIVE_WALLPAPER "$1"
  export OMAC_ACTIVE_WALLPAPER="$1"
}

# List the current theme's backgrounds, ● marking the active one.
omac::wallpaper::list() {
  local out; out="$(omac::wallpaper::_list)" \
    || { omac::error "no active theme or backgrounds (run: omac theme set <name>)"; return 1; }
  local -a bgs=("${(f)out}")
  local cur; cur="$(omac::wallpaper::current)"
  local f mark
  for f in "${bgs[@]}"; do
    [[ "${f:t}" == "$cur" ]] && mark="●" || mark=" "
    print -r -- "$mark ${f:t}"
  done
}

# Apply the next background for the current theme, wrapping at the end. No-op
# (with a note) when the theme carries a single wallpaper.
omac::wallpaper::next() {
  local theme; theme="$(omac::theme::current)" \
    || { omac::error "no active theme (run: omac theme set <name>)"; return 1; }
  local out; out="$(omac::theme::backgrounds "$theme")" \
    || { omac::warn "no backgrounds for $theme"; return 0; }
  local -a bgs=("${(f)out}")
  if (( ${#bgs} < 2 )); then
    omac::info "$theme has a single wallpaper — nothing to cycle"
    return 0
  fi
  # Index of the active background (basename match); default to 1 if stale.
  local cur; cur="$(omac::wallpaper::current)"
  local i idx=1
  for i in {1..${#bgs}}; do
    [[ "${bgs[$i]:t}" == "$cur" ]] && { idx=$i; break; }
  done
  local nextidx=$(( idx % ${#bgs} + 1 ))   # wrap: last -> first
  local nextfile="${bgs[$nextidx]}"
  omac::theme::apply_wallpaper_file "$nextfile"
  omac::wallpaper::persist "${nextfile:t}"
  omac::ok "wallpaper: ${nextfile:t} ($nextidx/${#bgs}, theme $theme)"
}
