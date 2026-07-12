# help: check the omac install for problems
typeset -i problems=0

_dr() {                 # _dr <label> <command...>
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    omac::ok "$label"
  else
    omac::error "$label"
    (( problems++ ))
  fi
}

_dr "Homebrew installed"        command -v brew
_dr "brew prefix on PATH"       omac::path_contains "$(omac::prefix)/bin"
_dr "OMAC_HOME exists"          test -d "$OMAC_HOME"
_dr "config dir exists"         test -d "$OMAC_CONFIG"
_dr "omac on PATH"              command -v omac

# Container stack — advisory only (warn, never fail the doctor): the tooling and
# the running daemon are optional and installed/started on demand.
if command -v colima >/dev/null 2>&1; then
  omac::ok "colima installed"
else
  omac::warn "colima not installed (run: omac software install containers)"
fi
if command -v docker >/dev/null 2>&1; then
  omac::ok "docker CLI installed"
else
  omac::warn "docker CLI not installed (run: omac software install containers)"
fi
if command -v colima >/dev/null 2>&1 && colima status >/dev/null 2>&1; then
  omac::ok "colima daemon running"
else
  omac::warn "colima daemon not running (run: omac services up)"
fi

if [[ "${ZSH_VERSION%%.*}" -ge 5 ]]; then
  omac::ok "zsh >= 5 (have $ZSH_VERSION)"
else
  omac::error "zsh >= 5 required (have $ZSH_VERSION)"
  (( problems++ ))
fi

if (( problems )); then
  omac::error "$problems problem(s) found — open a new shell or run: omac install"
  return 1
fi
omac::ok "all checks passed"
