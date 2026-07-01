# omac `bootstrap` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `omac` CLI command center, its curl-able installer, shell integration, and the update/migration engine — the foundation every later omac module plugs into, leaving a fresh shell with a working `omac` command and loaded user config.

**Architecture:** A zsh dispatcher (`bin/omac`) sources `lib/` helpers + the user's `config.zsh`, then resolves flat or two-level commands from `cmd/`, running each inside a function scope so `local`/`return` work. `boot.sh` preflights the platform, installs Homebrew, clones the repo, and runs an idempotent `install` that symlinks the CLI and writes a managed `~/.zprofile` block (`brew shellenv`) so `omac` is on PATH in new shells. Updates pull, `brew bundle`, then apply unran timestamped migrations tracked by marker files.

**Tech Stack:** zsh, Homebrew, git. No build step. Tests are plain zsh assertion scripts.

> **Platform:** Apple Silicon only; macOS 14 (Sonoma) / 15 (Sequoia) / 26 (Tahoe) — floor major 14, numbering jumped 15→26. **Environment:** all `zsh test/run.zsh` and `boot.sh` commands run on macOS (zsh is default there). The repo already exists at `~/Code/omac` with the design specs committed. Tests invoke the CLI as `zsh bin/omac …` (no exec-bit dependency) and override every real path via env vars into temp dirs — no test touches real `~/.zprofile`, PATH, or a git remote.

---

## File Structure

```
~/Code/omac/
  boot.sh                  # preflight + Homebrew + re-entrant clone + install
  version                  # version string, e.g. 0.1.0
  bin/omac                 # zsh dispatcher (flat + 2-level nested, sources config.zsh)
  lib/
    paths.zsh              # canonical locations + omac::prefix
    common.zsh             # logging, confirm, require_cmd, path_contains, managed-block helpers
    migrate.zsh            # omac::migrate engine
  cmd/
    help.zsh               # list commands
    version.zsh            # version + git sha
    path.zsh               # print resolved dirs
    doctor.zsh             # health checks (incl. PATH), nonzero exit on fail
    update.zsh             # pull + brew bundle + migrate
    install.zsh            # dirs + CLI symlink + .zprofile block + seed config (idempotent)
    uninstall.zsh          # remove symlink + .zprofile block + (confirm) config/state
  default/
    config.zsh             # starter user config seeded into ~/.config/omac
  themes/.gitkeep          # reserved for the theme module
  templates/.gitkeep       # reserved for the theme module
  migrations/
    20260618120000-example.zsh
  test/
    helper.zsh
    run.zsh
    test_harness.zsh
    test_paths.zsh
    test_dispatch.zsh
    test_nested.zsh
    test_version_path.zsh
    test_migrate.zsh
    test_update.zsh
    test_doctor.zsh
    test_install.zsh
    test_uninstall.zsh
```

**Conventions:**
- Each `cmd/*.zsh` carries a `# help: <one-line description>` comment, parsed by `omac help`.
- Command scripts are sourced inside the dispatcher's `omac::run` function (so `local`/`typeset`/`return` work).
- All locations honor env overrides (`OMAC_HOME`, `OMAC_CONFIG`, `OMAC_STATE`, `OMAC_PREFIX`, `OMAC_PROFILE`, `OMAC_CURRENT`) so tests run in temp dirs.

---

## Task 1: Test harness + repo skeleton

**Files:** Create `version`, `test/helper.zsh`, `test/run.zsh`, `test/test_harness.zsh`, `themes/.gitkeep`, `templates/.gitkeep`

- [ ] **Step 1: Create the version file and reserved dirs**

`version`:
```
0.1.0
```
Also create empty reserved dirs:
```bash
mkdir -p ~/Code/omac/themes ~/Code/omac/templates
touch ~/Code/omac/themes/.gitkeep ~/Code/omac/templates/.gitkeep
```

- [ ] **Step 2: Write the test helper**

`test/helper.zsh`:
```zsh
# Minimal zsh assertion helper. Source from each test file.
typeset -gi PASS=0 FAIL=0

check() {        # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    print -r -- "ok   - $1"; (( PASS++ ))
  else
    print -r -- "NOT OK - $1"
    print -r -- "    expected: [$2]"
    print -r -- "    actual:   [$3]"
    (( FAIL++ ))
  fi
}

contains() {     # contains <description> <needle> <haystack>
  if [[ "$3" == *"$2"* ]]; then
    print -r -- "ok   - $1"; (( PASS++ ))
  else
    print -r -- "NOT OK - $1 (missing substring: [$2])"; (( FAIL++ ))
  fi
}

finish() {
  print -r -- "--- $PASS passed, $FAIL failed ---"
  (( FAIL == 0 ))
}
```

- [ ] **Step 3: Write the runner**

`test/run.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
cd "${0:A:h}"
typeset -i rc=0
typeset f
for f in test_*.zsh; do
  print -r -- "== $f =="
  zsh "$f" || rc=1
done
exit $rc
```

- [ ] **Step 4: Write a self-test of the harness**

`test/test_harness.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
source "${0:A:h}/helper.zsh"
check "check compares equal strings" "abc" "abc"
contains "contains finds substring" "bc" "abcd"
finish
```

- [ ] **Step 5: Run the harness self-test**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `== test_harness.zsh ==`, two `ok` lines, `--- 2 passed, 0 failed ---`, exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add version test/helper.zsh test/run.zsh test/test_harness.zsh themes/.gitkeep templates/.gitkeep
git commit -m "test: add zsh assertion harness, version, reserved dirs"
```

---

## Task 2: Path + common helper libraries

**Files:** Create `lib/paths.zsh`, `lib/common.zsh`, `test/test_paths.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_paths.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

HOME=/tmp/fakehome
unset OMAC_CONFIG OMAC_STATE OMAC_PREFIX OMAC_PROFILE OMAC_CURRENT
source "$ROOT/lib/paths.zsh"
source "$ROOT/lib/common.zsh"

check "config defaults under HOME" "/tmp/fakehome/.config/omac" "$OMAC_CONFIG"
check "state defaults under HOME" "/tmp/fakehome/.local/state/omac" "$OMAC_STATE"
check "profile defaults to .zprofile" "/tmp/fakehome/.zprofile" "$OMAC_PROFILE"
check "current under config dir" "/tmp/fakehome/.config/omac/current" "$OMAC_CURRENT"
check "prefix honors OMAC_PREFIX" "/tmp/pfx" "$(OMAC_PREFIX=/tmp/pfx omac::prefix)"
check "require_cmd fails on missing" "1" "$(omac::require_cmd definitely-not-a-real-cmd >/dev/null 2>&1; print $?)"
# path_contains (run in subshells so the test process's own PATH is untouched)
check "path_contains finds dir" "0" "$(PATH=/a:/opt/homebrew/bin:/b; omac::path_contains /opt/homebrew/bin; print $?)"
check "path_contains rejects missing" "1" "$(PATH=/a:/b; omac::path_contains /opt/homebrew/bin; print $?)"
# safe, non-destructive file deploy (backup-on-overwrite)
tmp="$(mktemp -d)"
print -r -- one > "$tmp/src"
omac::install_file "$tmp/src" "$tmp/dst" >/dev/null 2>&1
check "install_file creates a missing dest" "one" "$(<"$tmp/dst")"
OMAC_YES=1 omac::install_file "$tmp/src" "$tmp/dst" >/dev/null 2>&1
# List-then-grep, not a bare glob: an unmatched glob is a hard error under zsh NOMATCH.
check "install_file leaves an identical dest un-backed-up" "0" "$(ls "$tmp" | grep -c omac-backup)"
print -r -- two > "$tmp/dst"
OMAC_YES=1 omac::install_file "$tmp/src" "$tmp/dst" >/dev/null 2>&1
check "install_file overwrites a differing dest" "one" "$(<"$tmp/dst")"
check "install_file backs up the replaced file" "1" "$(ls "$tmp" | grep -c omac-backup)"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_paths.zsh` errors (files don't exist yet).

- [ ] **Step 3: Write `lib/paths.zsh`**

`lib/paths.zsh`:
```zsh
# Canonical omac locations. Every value honors an env override for testing.
: ${OMAC_HOME:="${0:A:h:h}"}
: ${OMAC_CONFIG:="${XDG_CONFIG_HOME:-$HOME/.config}/omac"}
: ${OMAC_STATE:="${XDG_STATE_HOME:-$HOME/.local/state}/omac"}
: ${OMAC_MIGRATIONS_STATE:="$OMAC_STATE/migrations"}
: ${OMAC_PROFILE:="$HOME/.zprofile"}
: ${OMAC_CURRENT:="$OMAC_CONFIG/current"}
: ${OMAC_THEMES:="$OMAC_HOME/themes"}
: ${OMAC_TEMPLATES:="$OMAC_HOME/templates"}

omac::prefix() {
  if [[ -n "${OMAC_PREFIX:-}" ]]; then
    print -r -- "$OMAC_PREFIX"
  elif command -v brew >/dev/null 2>&1; then
    brew --prefix
  else
    print -r -- "/opt/homebrew"
  fi
}
```

- [ ] **Step 4: Write `lib/common.zsh`**

`lib/common.zsh`:
```zsh
# Logging, prompts, guards, and managed-block editing shared by every command.
omac::info()  { print -r -- "→ $*"; }
omac::ok()    { print -r -- "✓ $*"; }
omac::log()   { print -r -- "  $*"; }
omac::warn()  { print -r -- "! $*" >&2; }
omac::error() { print -r -- "✗ $*" >&2; }

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
  # non-interactive) → fail safe to "no".
  local reply
  read -r "reply?$1 [y/N] " </dev/tty 2>/dev/null || return 1
  [[ "$reply" == [yY]* ]]
}

omac::path_contains() {      # omac::path_contains <dir>
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *)        return 1 ;;
  esac
}

# Deploy a file idempotently and non-destructively (pattern mined from omakos'
# config scripts): absent → copy; byte-identical → skip; differing → show a diff,
# back the old file aside, then copy. Used by later modules (software/theme/dotfiles).
omac::install_file() {       # omac::install_file <src> <dest>
  local src="$1" dest="$2"
  mkdir -p "${dest:h}"
  if [[ ! -e "$dest" ]]; then
    cp "$src" "$dest"; omac::ok "installed ${dest:t}"; return 0
  fi
  if cmp -s "$src" "$dest"; then
    omac::log "up to date: ${dest:t}"; return 0
  fi
  omac::warn "${dest} differs from the omac version"
  command -v diff >/dev/null 2>&1 && diff -u "$dest" "$src"
  if omac::confirm "overwrite ${dest:t}? (a backup is kept)"; then
    omac::backup_path "$dest"
    cp "$src" "$dest"; omac::ok "installed ${dest:t}"
  else
    omac::log "kept existing ${dest:t}"
  fi
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
```

> Note: markers are function-local strings (`::` is not legal in a zsh parameter name). `grep -qF` matches them as fixed strings; `awk index()` avoids regex entirely, so the `>>>`/`<<<` characters are matched literally. `remove_block` buffers blank lines and discards the one(s) directly before the block, so `~/.zprofile` stays clean across cycles.

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_paths.zsh` shows all `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add lib/paths.zsh lib/common.zsh test/test_paths.zsh
git commit -m "feat: add path resolution and common shell helpers"
```

---

## Task 3: Dispatcher (flat resolution + config sourcing) + help

**Files:** Create `bin/omac`, `cmd/help.zsh`, `test/test_dispatch.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_dispatch.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)"

contains "no args prints usage" "Usage: omac" "$(zsh "$ROOT/bin/omac")"
contains "help lists itself" "help" "$(zsh "$ROOT/bin/omac" help)"
unknown_out="$(zsh "$ROOT/bin/omac" no-such-command 2>&1)"
contains "unknown command warns" "unknown command" "$unknown_out"
zsh "$ROOT/bin/omac" no-such-command >/dev/null 2>&1
check "unknown command exits nonzero" "1" "$?"

# config.zsh is sourced: an override placed there is visible to a command
print -r -- 'export OMAC_PROBE=seen-from-config' > "$OMAC_CONFIG/config.zsh"
print -r -- '# help: probe' > "$ROOT/cmd/_probe.zsh"
print -r -- 'print -r -- "PROBE=$OMAC_PROBE"' >> "$ROOT/cmd/_probe.zsh"
contains "config.zsh is sourced" "PROBE=seen-from-config" "$(zsh "$ROOT/bin/omac" _probe)"
rm -f "$ROOT/cmd/_probe.zsh"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_dispatch.zsh` errors (no `bin/omac` yet). (The `rm -f` cleanup still runs.)

- [ ] **Step 3: Write the dispatcher**

`bin/omac`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
setopt no_unset pipe_fail

# Resolve repo root from this script's real path (:A resolves symlinks).
export OMAC_HOME="${OMAC_HOME:-${0:A:h:h}}"
source "$OMAC_HOME/lib/paths.zsh"
source "$OMAC_HOME/lib/common.zsh"

# Load user config (overrides, default theme, etc.) if present.
[[ -r "$OMAC_CONFIG/config.zsh" ]] && source "$OMAC_CONFIG/config.zsh"

# Run a command script inside a function scope so `local` and `return` work.
omac::run() {
  local script="$1"; shift
  source "$script" "$@"
}

# Resolve <cmd> [<sub>] to "depth:scriptpath" (depth 2 = nested, 1 = flat).
omac::resolve() {
  local a="$1" b="${2:-}"
  if [[ -n "$b" && -f "$OMAC_HOME/cmd/$a/$b.zsh" ]]; then
    print -r -- "2:$OMAC_HOME/cmd/$a/$b.zsh"; return 0
  fi
  if [[ -f "$OMAC_HOME/cmd/$a.zsh" ]]; then
    print -r -- "1:$OMAC_HOME/cmd/$a.zsh"; return 0
  fi
  return 1
}

main() {
  local cmd="${1:-help}"
  (( $# )) && shift
  local match
  if match="$(omac::resolve "$cmd" "${1:-}")"; then
    local depth="${match%%:*}" script="${match#*:}"
    (( depth == 2 )) && (( $# )) && shift   # consume the subcommand token
    omac::run "$script" "$@"
    return $?
  fi
  omac::error "unknown command: $cmd${1:+ $1}"
  omac::run "$OMAC_HOME/cmd/help.zsh"
  return 1
}

main "$@"
exit $?
```

- [ ] **Step 4: Write the help command**

`cmd/help.zsh`:
```zsh
# help: show this help
print -r -- "omac — Omarchy-style desktop for macOS"
print -r -- ""
print -r -- "Usage: omac <command> [args]"
print -r -- ""
print -r -- "Commands:"
local f name desc
for f in "$OMAC_HOME"/cmd/*.zsh(N); do
  name="${f:t:r}"
  [[ "$name" == _* ]] && continue          # skip private/test commands
  desc="$(grep -m1 '^# help:' "$f" 2>/dev/null | sed 's/^# help: //')"
  printf "  %-10s %s\n" "$name" "$desc"
done
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_dispatch.zsh` shows 5 `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add bin/omac cmd/help.zsh test/test_dispatch.zsh
git commit -m "feat: add omac dispatcher (config sourcing) and help command"
```

---

## Task 4: Nested two-level command resolution

**Files:** Create `test/test_nested.zsh` (dispatcher already supports nesting from Task 3; this proves it with a fixture)

- [ ] **Step 1: Write the failing test**

`test/test_nested.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

# Build an isolated OMAC_HOME with a nested command fixture.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
mkdir -p "$fake/cmd/demo"
cat > "$fake/cmd/demo/run.zsh" <<'EOF'
# help: demo nested command
print -r -- "DEMO:$1"
EOF
cp "$ROOT/cmd/help.zsh" "$fake/cmd/help.zsh"

export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"

contains "nested command resolves and gets args" "DEMO:hello" "$(zsh "$fake/bin/omac" demo run hello)"
# falls back to flat when no nested match
contains "flat help still works" "Usage: omac" "$(zsh "$fake/bin/omac" help)"
finish
```

- [ ] **Step 2: Run it to verify it passes (resolution already implemented in Task 3)**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_nested.zsh` shows 2 `ok` lines; overall exit 0.
(If it fails, the bug is in `omac::resolve`/`main` from Task 3 — fix there, not here.)

- [ ] **Step 3: Commit**

```bash
cd ~/Code/omac
git add test/test_nested.zsh
git commit -m "test: prove two-level nested command resolution"
```

---

## Task 5: `version` and `path` commands

**Files:** Create `cmd/version.zsh`, `cmd/path.zsh`, `test/test_version_path.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_version_path.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)"

contains "version prints version string" "0.1.0" "$(zsh "$ROOT/bin/omac" version)"
path_out="$(zsh "$ROOT/bin/omac" path)"
contains "path prints OMAC_HOME" "OMAC_HOME=$ROOT" "$path_out"
contains "path prints config dir" "OMAC_CONFIG=" "$path_out"
contains "path prints themes dir" "themes=" "$path_out"
contains "path prints current symlink" "current=" "$path_out"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_version_path.zsh` reports NOT OK (commands missing → unknown command output).

- [ ] **Step 3: Write `cmd/version.zsh`**

`cmd/version.zsh`:
```zsh
# help: print the omac version
local v="unknown"
[[ -f "$OMAC_HOME/version" ]] && v="$(<"$OMAC_HOME/version")"
local sha=""
if command -v git >/dev/null 2>&1 && git -C "$OMAC_HOME" rev-parse --short HEAD >/dev/null 2>&1; then
  sha=" ($(git -C "$OMAC_HOME" rev-parse --short HEAD))"
fi
print -r -- "omac $v$sha"
```

- [ ] **Step 4: Write `cmd/path.zsh`**

`cmd/path.zsh`:
```zsh
# help: print resolved omac directories
print -r -- "OMAC_HOME=$OMAC_HOME"
print -r -- "OMAC_CONFIG=$OMAC_CONFIG"
print -r -- "OMAC_STATE=$OMAC_STATE"
print -r -- "themes=$OMAC_THEMES"
print -r -- "templates=$OMAC_TEMPLATES"
print -r -- "current=$OMAC_CURRENT"
print -r -- "profile=$OMAC_PROFILE"
print -r -- "prefix=$(omac::prefix)"
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_version_path.zsh` shows 5 `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add cmd/version.zsh cmd/path.zsh test/test_version_path.zsh
git commit -m "feat: add version and path commands"
```

---

## Task 6: Migration engine

**Files:** Create `lib/migrate.zsh`, `migrations/20260618120000-example.zsh`, `test/test_migrate.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_migrate.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_STATE="$(mktemp -d)"
export OMAC_MIGRATIONS_STATE="$OMAC_STATE/migrations"

source "$ROOT/lib/paths.zsh"
source "$ROOT/lib/common.zsh"
source "$ROOT/lib/migrate.zsh"

omac::migrate >/dev/null 2>&1
check "marker written after first run" "1" "$(ls "$OMAC_MIGRATIONS_STATE" | grep -c example)"
omac::migrate >/dev/null 2>&1
check "second run exits 0" "0" "$?"
check "marker still present" "1" "$(ls "$OMAC_MIGRATIONS_STATE" | grep -c example)"

# a failed migration can be skipped (separate ledger) without blocking the run
skip_out="$(
  fake="$(mktemp -d)"; ln -s "$ROOT/lib" "$fake/lib"; mkdir -p "$fake/migrations"
  print -r -- 'exit 1' > "$fake/migrations/29990101000000-boom.zsh"
  s="$(mktemp -d)"
  OMAC_HOME="$fake" OMAC_MIGRATIONS_STATE="$s/migrations"
  OMAC_YES=1 omac::migrate >/dev/null 2>&1
  print -r -- "$?:$(ls "$OMAC_MIGRATIONS_STATE/skipped" 2>/dev/null | grep -c boom)"
)"
check "skipping a failed migration exits 0" "0" "${skip_out%%:*}"
check "the skip is recorded in its own ledger" "1" "${skip_out##*:}"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_migrate.zsh` errors (no `lib/migrate.zsh`).

- [ ] **Step 3: Write the migration engine**

`lib/migrate.zsh`:
```zsh
# Run any migration whose marker is absent, in filename order, then mark it.
# A migration is marked ONLY after exit 0. On failure the user may skip it — the
# skip is recorded in a SEPARATE ledger so it neither reruns nor blocks the rest;
# declining aborts. (Skip-tracking mined from omarchy's omarchy-migrate.) Every
# migration MUST still be internally idempotent (check-then-act).
omac::migrate() {
  setopt local_options null_glob
  mkdir -p "$OMAC_MIGRATIONS_STATE" "$OMAC_MIGRATIONS_STATE/skipped"
  local f id
  for f in "$OMAC_HOME"/migrations/*.zsh; do
    id="${f:t:r}"
    [[ -e "$OMAC_MIGRATIONS_STATE/$id" || -e "$OMAC_MIGRATIONS_STATE/skipped/$id" ]] && continue
    omac::info "running migration $id"
    if zsh "$f"; then
      : > "$OMAC_MIGRATIONS_STATE/$id"
    elif omac::confirm "migration $id failed — skip and continue?"; then
      : > "$OMAC_MIGRATIONS_STATE/skipped/$id"
      omac::warn "skipped migration $id"
    else
      omac::error "migration failed: $id"
      return 1
    fi
  done
  return 0
}
```

- [ ] **Step 4: Write the example migration**

`migrations/20260618120000-example.zsh`:
```zsh
#!/usr/bin/env zsh
# Example migration: a no-op that demonstrates the pattern.
# RULE: migrations must be idempotent — they may partially run then rerun.
#   WRONG: echo 'x' >> ~/.zprofile        (doubles on rerun)
#   RIGHT: grep -qF 'x' ~/.zprofile || echo 'x' >> ~/.zprofile
exit 0
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_migrate.zsh` shows 5 `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add lib/migrate.zsh migrations/20260618120000-example.zsh test/test_migrate.zsh
git commit -m "feat: add idempotent migration engine"
```

---

## Task 7: `update` command

**Files:** Create `cmd/update.zsh`, `test/test_update.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_update.zsh` (points `OMAC_HOME` at a `.git`-free temp tree so the git-pull branch is skipped deterministically — no real network/repo access):
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

# Build a minimal, .git-free OMAC_HOME so `update` skips git pull and brew bundle.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"
mkdir -p "$fake/migrations"
cp "$ROOT/migrations/"*.zsh "$fake/migrations/"

export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_STATE="$(mktemp -d)"
export OMAC_MIGRATIONS_STATE="$OMAC_STATE/migrations"

out="$(zsh "$fake/bin/omac" update 2>&1)"
check "update exits 0" "0" "$?"
contains "update reports completion" "update complete" "$out"
check "update ran migrations" "1" "$(ls "$OMAC_MIGRATIONS_STATE" | grep -c example)"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_update.zsh` reports NOT OK (unknown command `update`).

- [ ] **Step 3: Write `cmd/update.zsh`**

`cmd/update.zsh`:
```zsh
# help: update omac (git pull, brew bundle, run migrations)
source "$OMAC_HOME/lib/migrate.zsh"

if command -v git >/dev/null 2>&1 && [[ -d "$OMAC_HOME/.git" ]]; then
  omac::info "pulling latest omac"
  git -C "$OMAC_HOME" pull --ff-only || omac::warn "git pull skipped/failed; continuing"
fi

if [[ -f "$OMAC_HOME/Brewfile" ]] && command -v brew >/dev/null 2>&1; then
  omac::info "running brew bundle"
  brew bundle --file="$OMAC_HOME/Brewfile" || omac::warn "brew bundle had issues; continuing"
fi

omac::migrate || return 1
omac::ok "update complete"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_update.zsh` shows 3 `ok` lines; overall exit 0.

- [ ] **Step 5: Commit**

```bash
cd ~/Code/omac
git add cmd/update.zsh test/test_update.zsh
git commit -m "feat: add update command (pull, bundle, migrate)"
```

---

## Task 8: `doctor` command (incl. PATH check + nonzero-exit contract)

**Files:** Create `cmd/doctor.zsh`, `test/test_doctor.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_doctor.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_STATE="$(mktemp -d)"

out="$(zsh "$ROOT/bin/omac" doctor 2>&1)"
contains "doctor checks Homebrew" "Homebrew" "$out"
contains "doctor checks PATH" "PATH" "$out"
contains "doctor checks zsh version" "zsh" "$out"

# nonzero-exit contract: force a guaranteed failure (prefix bin not on PATH)
OMAC_PREFIX=/definitely/not/on/path zsh "$ROOT/bin/omac" doctor >/dev/null 2>&1
check "doctor exits nonzero when a check fails" "1" "$?"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_doctor.zsh` reports NOT OK (unknown command `doctor`).

- [ ] **Step 3: Write `cmd/doctor.zsh`**

`cmd/doctor.zsh`:
```zsh
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_doctor.zsh` shows 4 `ok` lines; overall exit 0. (The first three are substring checks on output; the fourth asserts the forced-failure run exits 1.)

- [ ] **Step 5: Commit**

```bash
cd ~/Code/omac
git add cmd/doctor.zsh test/test_doctor.zsh
git commit -m "feat: add doctor health-check with PATH check and nonzero-exit contract"
```

---

## Task 9: `install` command (dirs + CLI symlink + shell integration + config)

**Files:** Create `cmd/install.zsh`, `default/config.zsh`, `test/test_install.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_install.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)/omac"
export OMAC_STATE="$(mktemp -d)/omac"
export OMAC_PREFIX="$(mktemp -d)"
export OMAC_PROFILE="$(mktemp -d)/.zprofile"

out="$(zsh "$ROOT/bin/omac" install 2>&1)"
check "install exits 0" "0" "$?"
check "CLI symlinked into prefix/bin" "$ROOT/bin/omac" "$(readlink "$OMAC_PREFIX/bin/omac")"
check "config seeded" "1" "$(test -f "$OMAC_CONFIG/config.zsh" && print 1 || print 0)"
check "zprofile block written" "1" "$(grep -c '>>> omac >>>' "$OMAC_PROFILE")"
contains "zprofile block has shellenv" "brew shellenv" "$(<"$OMAC_PROFILE")"
check "migrations baselined on first install" "1" "$(ls "$OMAC_STATE/migrations" 2>/dev/null | grep -c example)"

# second run is idempotent: still exits 0 and does NOT duplicate the block
zsh "$ROOT/bin/omac" install >/dev/null 2>&1
check "re-run still exits 0" "0" "$?"
check "block not duplicated" "1" "$(grep -c '>>> omac >>>' "$OMAC_PROFILE")"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_install.zsh` reports NOT OK (unknown command `install`).

- [ ] **Step 3: Write the default config**

`default/config.zsh`:
```zsh
# omac user config — sourced by bin/omac at startup (lives at ~/.config/omac/config.zsh).
# Override defaults here. Example:
#   export OMAC_DEFAULT_THEME="tokyo-night"
```

- [ ] **Step 4: Write `cmd/install.zsh`**

`cmd/install.zsh`:
```zsh
# help: install or repair the omac CLI, shell integration, and base config
typeset prefix bindir
prefix="$(omac::prefix)"
bindir="$prefix/bin"
mkdir -p "$bindir" "$OMAC_CONFIG" "$OMAC_STATE"

# Baseline migrations on first install: stamp every existing migration as already
# applied so a fresh machine never replays historical migrations (mined from
# omarchy's preflight/migrations.sh). Guarded on the ledger's ABSENCE because
# `install` doubles as the repair command — re-running must never mark a genuinely
# pending migration. New migrations arrive later via `omac update`.
if [[ ! -d "$OMAC_MIGRATIONS_STATE" ]]; then
  mkdir -p "$OMAC_MIGRATIONS_STATE"
  typeset m
  for m in "$OMAC_HOME"/migrations/*.zsh(N); do
    : > "$OMAC_MIGRATIONS_STATE/${m:t:r}"
  done
  omac::ok "baselined existing migrations as applied"
fi

ln -sf "$OMAC_HOME/bin/omac" "$bindir/omac"
omac::ok "linked omac -> $bindir/omac"

# Shell integration: ensure brew (and thus omac) is on PATH in new login shells.
omac::ensure_block "$OMAC_PROFILE" 'eval "$('"$prefix"'/bin/brew shellenv)"'
omac::ok "ensured shell integration in $OMAC_PROFILE"

# Seed user config from defaults (never clobber existing).
if [[ -d "$OMAC_HOME/default" ]]; then
  typeset f dest
  for f in "$OMAC_HOME"/default/*(N); do
    dest="$OMAC_CONFIG/${f:t}"
    if [[ -e "$dest" ]]; then
      omac::log "exists, skipping: ${f:t}"
    else
      cp -R "$f" "$dest"
      omac::ok "seeded ${f:t}"
    fi
  done
fi
omac::ok "install complete"
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_install.zsh` shows 8 `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add cmd/install.zsh default/config.zsh test/test_install.zsh
git commit -m "feat: add install with CLI symlink, shell integration, config seeding"
```

---

## Task 10: `uninstall` command

**Files:** Create `cmd/uninstall.zsh`, `test/test_uninstall.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_uninstall.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)/omac"
export OMAC_STATE="$(mktemp -d)/omac"
export OMAC_PREFIX="$(mktemp -d)"
export OMAC_PROFILE="$(mktemp -d)/.zprofile"
export OMAC_YES=1   # auto-confirm the config/state deletion

zsh "$ROOT/bin/omac" install >/dev/null 2>&1
zsh "$ROOT/bin/omac" uninstall >/dev/null 2>&1
check "uninstall exits 0" "0" "$?"
check "CLI symlink removed" "1" "$(test ! -e "$OMAC_PREFIX/bin/omac" && print 1 || print 0)"
check "zprofile block removed" "0" "$(grep -c '>>> omac >>>' "$OMAC_PROFILE")"
check "config removed (OMAC_YES)" "1" "$(test ! -d "$OMAC_CONFIG" && print 1 || print 0)"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_uninstall.zsh` reports NOT OK (unknown command `uninstall`).

- [ ] **Step 3: Write `cmd/uninstall.zsh`**

`cmd/uninstall.zsh`:
```zsh
# help: remove the omac CLI symlink, shell integration, and (optionally) config
typeset prefix bindir
prefix="$(omac::prefix)"
bindir="$prefix/bin"

if [[ -L "$bindir/omac" ]]; then
  rm -f "$bindir/omac"
  omac::ok "removed CLI symlink"
fi

omac::remove_block "$OMAC_PROFILE"
omac::ok "removed shell integration from $OMAC_PROFILE"

if omac::confirm "Also delete $OMAC_CONFIG and $OMAC_STATE?"; then
  rm -rf "$OMAC_CONFIG" "$OMAC_STATE"
  omac::ok "removed config and state"
fi
omac::ok "uninstall complete"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: `test_uninstall.zsh` shows 4 `ok` lines; overall exit 0.

- [ ] **Step 5: Commit**

```bash
cd ~/Code/omac
git add cmd/uninstall.zsh test/test_uninstall.zsh
git commit -m "feat: add uninstall command (reverse of install)"
```

---

## Task 11: `boot.sh` entry point (preflight + re-entrant clone)

**Files:** Create `boot.sh`

> Not unit-tested (it installs Homebrew and clones over the network). Verified by a syntax check plus a documented manual run.

- [ ] **Step 1: Write `boot.sh`**

`boot.sh`:
```zsh
#!/usr/bin/env zsh
# omac bootstrap — curl -fsSL <raw-url>/boot.sh | zsh
emulate -L zsh
setopt no_unset pipe_fail

OMAC_REPO="${OMAC_REPO:-https://github.com/afgallo/omac.git}"
OMAC_HOME="${OMAC_HOME:-$HOME/.local/share/omac}"
OMAC_MIN_MAJOR=14   # floor: Sonoma 14. Supported: Sonoma 14, Sequoia 15, Tahoe 26 (numbering jumped 15→26)

abort() { print -r -- "✗ $*" >&2; exit 1 }

# --- preflight ---
[[ "$(uname -s)" == "Darwin" ]] || abort "omac requires macOS"
[[ "$(uname -m)" == "arm64" ]]  || abort "omac requires Apple Silicon (arm64)"
os_major="$(sw_vers -productVersion | cut -d. -f1)"
(( os_major >= OMAC_MIN_MAJOR )) || \
  abort "omac requires macOS $OMAC_MIN_MAJOR+ (Sonoma or newer); found $(sw_vers -productVersion)"
ping -c1 -t5 github.com >/dev/null 2>&1 || abort "no network: cannot reach github.com"

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
```

- [ ] **Step 2: Syntax-check boot.sh and make CLI executable**

Run: `zsh -n ~/Code/omac/boot.sh && chmod +x ~/Code/omac/boot.sh ~/Code/omac/bin/omac && echo OK`
Expected: prints `OK` with no syntax errors. (The chmod is belt-and-suspenders; tests don't depend on it since they invoke `zsh bin/omac`.)

- [ ] **Step 3: Run the full suite once more**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: every `test_*.zsh` group passes; overall exit 0.

- [ ] **Step 4: Commit**

```bash
cd ~/Code/omac
git add boot.sh
git commit -m "feat: add boot.sh installer with preflight and re-entrant clone"
```

- [ ] **Step 5: Manual smoke test (on a Mac — do not automate)**

1. **Fresh-shell test (the BLOCKER this guards):** from a clone, run `zsh bin/omac install`, then open a **brand-new terminal window** and run `omac doctor` → all checks pass, including "brew prefix on PATH". This proves the `.zprofile` block works.
2. `omac help` → lists `help, version, path, doctor, update, install, uninstall`.
3. `omac update` → pulls, (optionally) bundles, runs migrations, prints `update complete`.
4. **Uninstall round-trip:** `omac uninstall` (answer `y`), confirm the symlink and `~/.zprofile` block are gone, then re-run `zsh bin/omac install` → clean re-install.
5. (Optional) `OMAC_REPO=<your-fork> zsh boot.sh` end-to-end on a spare/clean Mac.

---

## Self-Review Notes

- **Spec coverage:** preflight/prereqs (Task 11), install locations + reserved layout (Tasks 1,2,5), `boot.sh` + re-entrant clone (Task 11), Homebrew bootstrap (Task 11), shell integration `.zprofile` block (Task 9, tested), config sourcing (Task 3, tested), dispatcher flat + nested (Tasks 3,4), `help`/`version`/`path`/`doctor`/`update`/`install`/`uninstall` (Tasks 3,5,7,8,9,10), doctor PATH check + nonzero-exit contract (Task 8, tested), migration engine + idempotency rule (Task 6), idempotency of install/block (Task 9 tests). Every spec section maps to a task.
- **Review fixes applied:** BLOCKER config-never-sourced → Task 3 + test; BLOCKER PATH-in-fresh-shell → Task 9 `.zprofile` block + Task 8 PATH check + Task 11 manual fresh-shell test; MAJOR doctor/spec divergence → Task 8; MAJOR reserved theme layout → Tasks 1,2,5 + master spec; MAJOR uninstall → Task 10; MAJOR re-entrant clone → Task 11; MAJOR nested resolution → Tasks 3,4; MINOR migration idempotency → Task 6 rule/comment; test fixes: exec-bit (all tests use `zsh bin/omac`), doctor exit assertion (Task 8), update real-git-pull (Task 7 `.git`-free temp tree).
- **Reference mining (omakos):** the diff-aware, backup-on-overwrite `omac::install_file` / `omac::backup_path` helpers and the `/dev/tty` read in `omac::confirm` are adapted from [yatish27/omakos](https://github.com/yatish27/omakos)' config scripts. Deliberately **not** copied: its zip-download + `rm -rf` installer (boot.sh keeps the re-entrant git clone) and its inverted/Linux-only `check_internet_connection` (boot.sh keeps the correct `ping -t` preflight).
- **Reference mining (omarchy):** two mechanisms adopted from [basecamp/omarchy](https://github.com/basecamp/omarchy) that omac's earlier draft lacked — (1) **fresh-install migration baselining** (Task 9: `install` stamps all existing migrations as applied so a new machine never replays history; guarded on ledger-absence because omac's `install` also repairs, unlike omarchy's install-only `preflight/migrations.sh`), and (2) **skip-tracking for failed migrations** (Task 6: a failure can be skipped into a separate `migrations/skipped/` ledger so it neither reruns nor blocks the rest, instead of hard-aborting the whole update). Not adopted: omarchy's release-channel/mirror system and per-bin `# omarchy:key=value` metadata beyond omac's existing `# help:` + `_`-prefix conventions (out of scope for a personal single-channel tool).
- **Type/name consistency:** helpers `omac::info/ok/log/warn/error/require_cmd/confirm/path_contains/install_file/backup_path/ensure_block/remove_block/prefix/run/resolve/migrate`; params `omac::block_begin/omac::block_end`; env `OMAC_HOME/CONFIG/STATE/MIGRATIONS_STATE/PROFILE/CURRENT/THEMES/TEMPLATES/PREFIX/YES/REPO` — used identically across all tasks.
- **Private command convention:** `cmd/_*.zsh` are hidden from `help` (used by the Task 3 config-sourcing fixture).
