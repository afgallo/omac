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
