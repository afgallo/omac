# Logging, prompts, guards, and managed-block editing shared by every command.
omac::info()  { print -r -- "→ $*"; }
omac::ok()    { print -r -- "✓ $*"; }
omac::log()   { print -r -- "  $*"; }
omac::warn()  { print -r -- "! $*" >&2; }
omac::error() { print -r -- "✗ $*" >&2; }

# Read `key = "value"` from a flat TOML-ish file (colors.toml / apps.toml /
# font.toml). Prints the unquoted value; empty + return 1 if the key is absent.
omac::toml_get() {           # omac::toml_get <file> <key>
  local file="$1" key="$2" line
  [[ -f "$file" ]] || return 1
  line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | head -1)" || true
  [[ -n "$line" ]] || return 1
  line="${line#*=}"                       # drop `key =`
  line="${line##[[:space:]]}"             # trim leading space
  line="${line%%[[:space:]]}"             # trim trailing space
  line="${line#\"}"; line="${line%\"}"    # strip surrounding quotes
  print -r -- "$line"
}

omac::require_cmd() {        # omac::require_cmd <cmd>
  if ! command -v "$1" >/dev/null 2>&1; then
    omac::error "required command not found: $1"
    return 1
  fi
}

omac::confirm() {            # omac::confirm <prompt> ; OMAC_YES=1 auto-accepts
  [[ "${OMAC_YES:-0}" == 1 ]] && return 0
  # Read from the controlling terminal, not stdin: under `curl … | zsh` stdin is
  # the script itself, so a plain `read` never reaches the user. No tty (CI /
  # non-interactive) → fail safe to "no". Print the prompt ourselves: zsh
  # suppresses `read`'s own prompt in a non-interactive shell (a script), so
  # relying on `read "var?prompt"` would leave the user staring at a blank line.
  local reply
  print -n -- "$1 [y/N] " >/dev/tty 2>/dev/null || return 1
  read -r reply </dev/tty 2>/dev/null || return 1
  [[ "$reply" == [yY]* ]]
}

omac::path_contains() {      # omac::path_contains <dir>
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *)        return 1 ;;
  esac
}

# Deploy a file idempotently and non-destructively (pattern mined from omakos'
# config scripts): absent → copy; byte-identical → skip; differing → warn and
# prompt, backing the old file aside before overwrite. Declining the prompt is
# treated as an abort: the helper returns non-zero so callers stop rather than
# silently skip the file. Used by later modules (software/theme/dotfiles).
omac::install_file() {       # omac::install_file <src> <dest>
  local src="$1" dest="$2"
  mkdir -p "${dest:h}"
  if [[ ! -e "$dest" ]]; then
    cp "$src" "$dest"; omac::ok "installed ${dest:t}"; return 0
  fi
  if cmp -s "$src" "$dest"; then
    omac::log "up to date: ${dest:t}"; return 0
  fi
  omac::warn "${dest} already exists and differs from omac's version"
  if omac::confirm "Overwrite it with omac's version? Your current file is backed up first; answer N to keep yours."; then
    omac::backup_path "$dest"
    cp "$src" "$dest"; omac::ok "installed ${dest:t}"; return 0
  fi
  omac::error "kept your ${dest:t} — omac's version was not installed"
  return 1
}

# Rename an existing path aside with a timestamp — no data loss on overwrite.
# Uses the zsh/datetime `strftime` builtin (no external `date` subprocess).
# NB: the local is `target`, NOT `path` — in zsh `$path` is tied to `$PATH`, so
# `local path=…` would clobber PATH for this scope and break `mv`.
omac::backup_path() {        # omac::backup_path <target>
  local target="$1"
  [[ -e "$target" ]] || return 0
  zmodload zsh/datetime           # provides both `strftime` and `$EPOCHSECONDS`
  local stamp; strftime -s stamp '%Y%m%d_%H%M%S' "$EPOCHSECONDS"
  local backup="$target.omac-backup.$stamp"
  mv "$target" "$backup"
  omac::warn "backed up existing → ${backup:t}"
}

# Marker-delimited managed block in a config file (idempotent add, marker-based remove).
# Markers are kept as function-local constants (':: ' is NOT legal in a zsh variable name).
omac::ensure_block() {       # omac::ensure_block <file> <content>
  local file="$1" content="$2"
  local begin="# >>> omac >>>" end="# <<< omac <<<"
  mkdir -p "${file:h}"
  [[ -f "$file" ]] || : > "$file"
  if grep -qF "$begin" "$file" 2>/dev/null; then
    return 0   # already managed; leave as-is
  fi
  {
    print -r -- ""
    print -r -- "$begin"
    print -r -- "$content"
    print -r -- "$end"
  } >> "$file"
}

omac::remove_block() {       # omac::remove_block <file>
  local file="$1"
  [[ -f "$file" ]] || return 0
  local begin="# >>> omac >>>" end="# <<< omac <<<"
  local tmp="$file.omac.tmp"
  # Remove begin..end inclusive AND any blank line(s) immediately preceding the
  # block, so repeated install/uninstall cycles don't accumulate blank lines.
  awk -v b="$begin" -v e="$end" '
    index($0, b) { blanks=0; skip=1; next }
    skip         { if (index($0, e)) skip=0; next }
    /^$/         { blanks++; next }
                 { while (blanks>0) { print ""; blanks-- } print }
    END          { while (blanks>0) { print ""; blanks-- } }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# Upsert one `export KEY="VALUE"` line inside the managed block of
# $OMAC_CONFIG/config.zsh, preserving every other export the block already holds.
# The theme and font modules both persist here, so a plain remove+ensure (which
# would drop the sibling's line) is not enough — this reads the current exports,
# replaces just <key>, and rewrites the block.
omac::config_set() {         # omac::config_set <key> <value>
  local key="$1" val="$2" file="$OMAC_CONFIG/config.zsh"
  local begin="# >>> omac >>>" end="# <<< omac <<<"
  local -a lines; local inblock=0 line
  if [[ -f "$file" ]]; then
    while IFS= read -r line; do
      [[ "$line" == "$begin" ]] && { inblock=1; continue; }
      [[ "$line" == "$end" ]]   && { inblock=0; continue; }
      (( inblock )) || continue
      [[ "$line" == "export $key="* ]] && continue   # drop the key we're setting
      [[ -n "$line" ]] && lines+=("$line")           # keep the siblings
    done < "$file"
  fi
  lines+=("export $key=\"$val\"")
  omac::remove_block "$file"
  omac::ensure_block "$file" "${(F)lines}"           # (F) = join array with newlines
}

# Upsert a top-level "<key>": <raw> pair in a flat JSON settings file (VS
# Code/Cursor style). <raw> is written verbatim, so callers quote strings
# (\"$val\") and pass numbers bare. Creates the file, replaces an existing value,
# or inserts after the first `{`. Simple by design — no nested keys, and values
# must not contain `,`, `}`, or sed metacharacters (font names don't).
omac::json_set_raw() {       # omac::json_set_raw <file> <key> <raw-value>
  local f="$1" key="$2" raw="$3"
  local tmp="$f.omac.tmp"    # separate line: zsh can't read $f on its own local
  mkdir -p "${f:h}"
  if [[ ! -f "$f" ]]; then
    printf '{\n  "%s": %s\n}\n' "$key" "$raw" > "$f"
    return 0
  fi
  if grep -q "\"$key\"" "$f"; then
    sed -E 's#("'"$key"'"[[:space:]]*:[[:space:]]*)[^,}]*#\1'"$raw"'#' "$f" > "$tmp" && mv "$tmp" "$f"
  else
    awk -v line="  \"$key\": $raw," '
      !done && /\{/ { print; print line; done=1; next } { print }
    ' "$f" > "$tmp" && mv "$tmp" "$f"
  fi
}

# Send <signal> to every process whose executable basename is <name>.
# pkill can't reach macOS app bundles: the kernel proc name it matches against
# is the executable *path* truncated to 16 chars ("/Applications/Gh" for
# Ghostty), so `pkill -x ghostty` silently signals nothing. ps reports the full
# executable path, so match its basename and signal directly. Best-effort:
# always returns 0 (nothing running is fine). `command kill` so tests can stub
# the external kill instead of hitting the zsh builtin.
omac::signal_app() {         # omac::signal_app <signal> <exe-basename>
  local sig="$1" name="$2" pid comm
  ps -axo pid=,comm= 2>/dev/null | while read -r pid comm; do
    [[ "${comm:t:l}" == "${name:l}" ]] && command kill "-$sig" "$pid" 2>/dev/null
  done
  return 0
}
