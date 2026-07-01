#!/usr/bin/env zsh
# omac bootstrap — curl -fsSL <raw-url>/boot.sh | zsh
emulate -L zsh
setopt no_unset pipe_fail

OMAC_REPO="${OMAC_REPO:-https://github.com/afgallo/omac.git}"
OMAC_HOME="${OMAC_HOME:-$HOME/.local/share/omac}"
OMAC_MIN_MAJOR=14   # macOS Sonoma; supports 14 (N-1) and 15 (N)

abort() { print -r -- "✗ $*" >&2; exit 1 }

# --- preflight ---
[[ "$(uname -s)" == "Darwin" ]] || abort "omac requires macOS"
[[ "$(uname -m)" == "arm64" ]]  || abort "omac requires Apple Silicon (arm64)"
os_major="$(sw_vers -productVersion | cut -d. -f1)"
(( os_major >= OMAC_MIN_MAJOR )) || \
  abort "omac requires macOS $OMAC_MIN_MAJOR+ (Sonoma); found $(sw_vers -productVersion)"
# Reachability check over HTTPS (what `git clone` actually uses) rather than ICMP:
# many networks block/deprioritize ping while HTTPS works, so curl avoids false negatives.
curl -fsS --max-time 5 -o /dev/null https://github.com \
  || abort "no network: cannot reach github.com over HTTPS"

# --- Xcode Command Line Tools ---
if ! xcode-select -p >/dev/null 2>&1; then
  print -r -- "→ installing Xcode Command Line Tools"
  xcode-select --install || true
  abort "rerun boot.sh once Command Line Tools finish installing"
fi

# --- Homebrew ---
if ! command -v brew >/dev/null 2>&1; then
  print -r -- "→ installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || abort "Homebrew install failed"
fi
BREW="$(command -v brew || print /opt/homebrew/bin/brew)"
eval "$("$BREW" shellenv)"

# --- clone or update (re-entrant) ---
if [[ -d "$OMAC_HOME/.git" ]]; then
  print -r -- "→ updating existing omac"
  git -C "$OMAC_HOME" pull --ff-only || abort "git pull failed; resolve $OMAC_HOME manually"
elif [[ -e "$OMAC_HOME" ]]; then
  print -r -- "! $OMAC_HOME exists but is not a git repo (interrupted clone?)"
  if [[ -t 0 ]]; then
    read -r "reply?Remove and re-clone? [y/N] "
    [[ "$reply" == [yY]* ]] || abort "leaving $OMAC_HOME as-is"
  fi
  rm -rf "$OMAC_HOME"
  git clone "$OMAC_REPO" "$OMAC_HOME" || abort "git clone failed"
else
  print -r -- "→ cloning omac"
  mkdir -p "${OMAC_HOME:h}"
  git clone "$OMAC_REPO" "$OMAC_HOME" || abort "git clone failed"
fi

# --- core install ---
OMAC_HOME="$OMAC_HOME" zsh "$OMAC_HOME/bin/omac" install || abort "omac install failed"

print -r -- ""
print -r -- "✓ omac installed. Open a new terminal, then run: omac doctor"
