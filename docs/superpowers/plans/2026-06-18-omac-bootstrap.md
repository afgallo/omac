# omac `bootstrap` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `omac` CLI command center, its curl-able installer, and the update/migration engine — the foundation every later omac module plugs into.

**Architecture:** A zsh dispatcher (`bin/omac`) sources small per-command scripts from `cmd/`, sharing helpers in `lib/`. Commands run inside a function scope so `local` works and exit status propagates. A `boot.sh` entry point installs Homebrew + clones the repo + runs the core install. Updates pull the repo, run `brew bundle`, then apply unran timestamped migrations tracked by marker files.

**Tech Stack:** zsh, Homebrew, git. No build step. Tests are plain zsh assertion scripts.

> **Environment note:** all `zsh test/run.zsh` commands run on macOS (zsh is the default shell there). This plan's commands assume zsh ≥ 5. The repo already exists at `~/Code/omac` with the design specs committed.

---

## File Structure

```
~/Code/omac/
  boot.sh                  # curl-able entry point (Homebrew + clone + install)
  version                  # version string, e.g. 0.1.0
  bin/omac                 # zsh dispatcher
  lib/
    paths.zsh              # canonical locations + omac::prefix
    common.zsh             # logging, confirm, require_cmd
    migrate.zsh            # omac::migrate engine
  cmd/
    help.zsh               # list commands
    version.zsh            # print version + git sha
    path.zsh              # print resolved dirs
    doctor.zsh            # health checks
    update.zsh           # pull + brew bundle + migrate
    install.zsh          # link CLI + seed config (idempotent)
  default/
    config.zsh            # starter user config seeded into ~/.config/omac
  migrations/
    20260618120000-example.zsh   # no-op example migration
  test/
    helper.zsh            # assertion helpers
    run.zsh               # runner: executes every test_*.zsh
    test_paths.zsh
    test_dispatch.zsh
    test_version_path.zsh
    test_migrate.zsh
    test_update.zsh
    test_doctor.zsh
    test_install.zsh
```

**Conventions:**
- Each `cmd/*.zsh` carries a `# help: <one-line description>` comment, parsed by `omac help`.
- Command scripts are sourced inside the dispatcher's `omac::run` function, so `local`/`typeset` and `return N` behave as in a function.
- All locations honor env overrides (`OMAC_HOME`, `OMAC_CONFIG`, `OMAC_STATE`, `OMAC_PREFIX`) so tests run in temp dirs.

---

## Task 1: Test harness + repo skeleton

**Files:**
- Create: `version`
- Create: `test/helper.zsh`
- Create: `test/run.zsh`
- Create: `test/test_harness.zsh`

- [ ] **Step 1: Create the version file**

`version`:
```
0.1.0
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

Run: `zsh test/run.zsh`
Expected: prints `== test_harness.zsh ==`, two `ok` lines, `--- 2 passed, 0 failed ---`, exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add version test/helper.zsh test/run.zsh test/test_harness.zsh
git commit -m "test: add zsh assertion harness and version file"
```

---

## Task 2: Path + common helper libraries

**Files:**
- Create: `lib/paths.zsh`
- Create: `lib/common.zsh`
- Create: `test/test_paths.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_paths.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

# defaults derive from HOME when no overrides set
HOME=/tmp/fakehome
unset OMAC_CONFIG OMAC_STATE OMAC_PREFIX
source "$ROOT/lib/paths.zsh"
source "$ROOT/lib/common.zsh"
check "config defaults under HOME" "/tmp/fakehome/.config/omac" "$OMAC_CONFIG"
check "state defaults under HOME" "/tmp/fakehome/.local/state/omac" "$OMAC_STATE"
check "prefix honors OMAC_PREFIX" "/tmp/pfx" "$(OMAC_PREFIX=/tmp/pfx omac::prefix)"
check "require_cmd fails on missing" "1" "$(omac::require_cmd definitely-not-a-real-cmd >/dev/null 2>&1; print $?)"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh test/run.zsh`
Expected: `test_paths.zsh` reports NOT OK / errors (files don't exist yet).

- [ ] **Step 3: Write `lib/paths.zsh`**

`lib/paths.zsh`:
```zsh
# Canonical omac locations. Every value honors an env override for testing.
: ${OMAC_HOME:="${0:A:h:h}"}
: ${OMAC_CONFIG:="${XDG_CONFIG_HOME:-$HOME/.config}/omac"}
: ${OMAC_STATE:="${XDG_STATE_HOME:-$HOME/.local/state}/omac"}
: ${OMAC_MIGRATIONS_STATE:="$OMAC_STATE/migrations"}

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
# Logging, prompts, and guards shared by every command.
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
  local reply
  read -r "reply?$1 [y/N] "
  [[ "$reply" == [yY]* ]]
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `zsh test/run.zsh`
Expected: `test_paths.zsh` shows 4 `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add lib/paths.zsh lib/common.zsh test/test_paths.zsh
git commit -m "feat: add path resolution and common shell helpers"
```

---

## Task 3: Dispatcher + help command

**Files:**
- Create: `bin/omac`
- Create: `cmd/help.zsh`
- Create: `test/test_dispatch.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_dispatch.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"

contains "no args prints usage" "Usage: omac" "$("$ROOT/bin/omac")"
contains "help lists itself" "help" "$("$ROOT/bin/omac" help)"
unknown_out="$("$ROOT/bin/omac" no-such-command 2>&1)"
contains "unknown command warns" "unknown command" "$unknown_out"
"$ROOT/bin/omac" no-such-command >/dev/null 2>&1
check "unknown command exits nonzero" "1" "$?"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh test/run.zsh`
Expected: `test_dispatch.zsh` errors (no `bin/omac` yet).

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

# Run a command script inside a function scope so `local` and `return` work.
omac::run() {
  local script="$1"; shift
  source "$script" "$@"
}

main() {
  local cmd="${1:-help}"
  (( $# )) && shift
  if [[ -f "$OMAC_HOME/cmd/$cmd.zsh" ]]; then
    omac::run "$OMAC_HOME/cmd/$cmd.zsh" "$@"
    return $?
  fi
  omac::error "unknown command: $cmd"
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
  desc="$(grep -m1 '^# help:' "$f" 2>/dev/null | sed 's/^# help: //')"
  printf "  %-9s %s\n" "$name" "$desc"
done
```

- [ ] **Step 5: Make the dispatcher executable**

Run: `chmod +x ~/Code/omac/bin/omac ~/Code/omac/boot.sh 2>/dev/null; chmod +x ~/Code/omac/bin/omac`
(boot.sh is created later; the trailing command guarantees `bin/omac` is +x now.)

- [ ] **Step 6: Run the test to verify it passes**

Run: `zsh test/run.zsh`
Expected: `test_dispatch.zsh` shows 4 `ok` lines; overall exit 0.

- [ ] **Step 7: Commit**

```bash
cd ~/Code/omac
git add bin/omac cmd/help.zsh test/test_dispatch.zsh
git commit -m "feat: add omac dispatcher and help command"
```

---

## Task 4: `version` and `path` commands

**Files:**
- Create: `cmd/version.zsh`
- Create: `cmd/path.zsh`
- Create: `test/test_version_path.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_version_path.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"

contains "version prints version string" "0.1.0" "$("$ROOT/bin/omac" version)"
path_out="$("$ROOT/bin/omac" path)"
contains "path prints OMAC_HOME" "OMAC_HOME=$ROOT" "$path_out"
contains "path prints config dir" "OMAC_CONFIG=" "$path_out"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh test/run.zsh`
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
print -r -- "prefix=$(omac::prefix)"
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `zsh test/run.zsh`
Expected: `test_version_path.zsh` shows 3 `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add cmd/version.zsh cmd/path.zsh test/test_version_path.zsh
git commit -m "feat: add version and path commands"
```

---

## Task 5: Migration engine

**Files:**
- Create: `lib/migrate.zsh`
- Create: `migrations/20260618120000-example.zsh`
- Create: `test/test_migrate.zsh`

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
# second run must be a no-op (no error, marker still present)
omac::migrate >/dev/null 2>&1
check "second run exits 0" "0" "$?"
check "marker still present" "1" "$(ls "$OMAC_MIGRATIONS_STATE" | grep -c example)"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh test/run.zsh`
Expected: `test_migrate.zsh` errors (no `lib/migrate.zsh`).

- [ ] **Step 3: Write the migration engine**

`lib/migrate.zsh`:
```zsh
# Run any migration whose marker is absent, in filename order, then mark it.
omac::migrate() {
  setopt local_options null_glob
  mkdir -p "$OMAC_MIGRATIONS_STATE"
  local f id
  for f in "$OMAC_HOME"/migrations/*.zsh; do
    id="${f:t:r}"
    [[ -e "$OMAC_MIGRATIONS_STATE/$id" ]] && continue
    omac::info "running migration $id"
    if zsh "$f"; then
      : > "$OMAC_MIGRATIONS_STATE/$id"
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
# Real migrations must be idempotent and do exactly one thing.
exit 0
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `zsh test/run.zsh`
Expected: `test_migrate.zsh` shows 3 `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add lib/migrate.zsh migrations/20260618120000-example.zsh test/test_migrate.zsh
git commit -m "feat: add idempotent migration engine"
```

---

## Task 6: `update` command

**Files:**
- Create: `cmd/update.zsh`
- Create: `test/test_update.zsh`

- [ ] **Step 1: Write the failing test**

`test/test_update.zsh`:
```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
export OMAC_HOME="$ROOT"
export OMAC_STATE="$(mktemp -d)"
export OMAC_MIGRATIONS_STATE="$OMAC_STATE/migrations"

out="$("$ROOT/bin/omac" update 2>&1)"
check "update exits 0" "0" "$?"
contains "update reports completion" "update complete" "$out"
check "update ran migrations" "1" "$(ls "$OMAC_MIGRATIONS_STATE" | grep -c example)"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh test/run.zsh`
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

Run: `zsh test/run.zsh`
Expected: `test_update.zsh` shows 3 `ok` lines; overall exit 0.
(Note: with no `Brewfile` and a clean git tree the guarded steps are skipped — that is correct.)

- [ ] **Step 5: Commit**

```bash
cd ~/Code/omac
git add cmd/update.zsh test/test_update.zsh
git commit -m "feat: add update command (pull, bundle, migrate)"
```

---

## Task 7: `doctor` command

**Files:**
- Create: `cmd/doctor.zsh`
- Create: `test/test_doctor.zsh`

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

out="$("$ROOT/bin/omac" doctor 2>&1)"
contains "doctor checks Homebrew" "Homebrew" "$out"
contains "doctor checks OMAC_HOME" "OMAC_HOME" "$out"
contains "doctor checks zsh version" "zsh" "$out"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh test/run.zsh`
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

_dr "Homebrew installed"     command -v brew
_dr "OMAC_HOME exists"       test -d "$OMAC_HOME"
_dr "config dir exists"      test -d "$OMAC_CONFIG"
_dr "omac on PATH"           command -v omac

if [[ "${ZSH_VERSION%%.*}" -ge 5 ]]; then
  omac::ok "zsh >= 5 (have $ZSH_VERSION)"
else
  omac::error "zsh >= 5 required (have $ZSH_VERSION)"
  (( problems++ ))
fi

if (( problems )); then
  omac::error "$problems problem(s) found"
  return 1
fi
omac::ok "all checks passed"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `zsh test/run.zsh`
Expected: `test_doctor.zsh` shows 3 `ok` lines; overall exit 0. (The doctor *command* may itself report problems like missing Homebrew on a dev box — that's fine; the test only checks that the relevant check lines are present.)

- [ ] **Step 5: Commit**

```bash
cd ~/Code/omac
git add cmd/doctor.zsh test/test_doctor.zsh
git commit -m "feat: add doctor health-check command"
```

---

## Task 8: `install` command + default config

**Files:**
- Create: `cmd/install.zsh`
- Create: `default/config.zsh`
- Create: `test/test_install.zsh`

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

out="$("$ROOT/bin/omac" install 2>&1)"
check "install exits 0" "0" "$?"
check "CLI symlinked into prefix/bin" "$ROOT/bin/omac" "$(readlink "$OMAC_PREFIX/bin/omac")"
check "config seeded" "1" "$(test -f "$OMAC_CONFIG/config.zsh" && print 1 || print 0)"
# second run is idempotent
"$ROOT/bin/omac" install >/dev/null 2>&1
check "re-run still exits 0" "0" "$?"
finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh test/run.zsh`
Expected: `test_install.zsh` reports NOT OK (unknown command `install`).

- [ ] **Step 3: Write the default config**

`default/config.zsh`:
```zsh
# omac user config — sourced by omac at startup.
# Override defaults here. Lives at ~/.config/omac/config.zsh.
# Example:
#   export OMAC_DEFAULT_THEME="tokyo-night"
```

- [ ] **Step 4: Write `cmd/install.zsh`**

`cmd/install.zsh`:
```zsh
# help: install or repair the omac CLI and base config
typeset prefix bindir
prefix="$(omac::prefix)"
bindir="$prefix/bin"
mkdir -p "$bindir" "$OMAC_CONFIG" "$OMAC_STATE"

ln -sf "$OMAC_HOME/bin/omac" "$bindir/omac"
omac::ok "linked omac -> $bindir/omac"

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

Run: `zsh test/run.zsh`
Expected: `test_install.zsh` shows 4 `ok` lines; overall exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/Code/omac
git add cmd/install.zsh default/config.zsh test/test_install.zsh
git commit -m "feat: add install command and default config seeding"
```

---

## Task 9: `boot.sh` entry point

**Files:**
- Create: `boot.sh`

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

abort() { print -r -- "✗ $*" >&2; exit 1 }

[[ "$(uname -s)" == "Darwin" ]] || abort "omac requires macOS"

if ! xcode-select -p >/dev/null 2>&1; then
  print -r -- "→ installing Xcode Command Line Tools"
  xcode-select --install || true
  abort "rerun boot.sh once Command Line Tools finish installing"
fi

if ! command -v brew >/dev/null 2>&1; then
  print -r -- "→ installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$("$(command -v brew || print /opt/homebrew/bin/brew)" shellenv)"

if [[ -d "$OMAC_HOME/.git" ]]; then
  print -r -- "→ updating existing omac"
  git -C "$OMAC_HOME" pull --ff-only || true
else
  print -r -- "→ cloning omac"
  mkdir -p "${OMAC_HOME:h}"
  git clone "$OMAC_REPO" "$OMAC_HOME"
fi

OMAC_HOME="$OMAC_HOME" "$OMAC_HOME/bin/omac" install

print -r -- ""
print -r -- "✓ omac installed. Open a new terminal, then run: omac doctor"
```

- [ ] **Step 2: Syntax-check boot.sh and confirm executables**

Run: `zsh -n ~/Code/omac/boot.sh && chmod +x ~/Code/omac/boot.sh ~/Code/omac/bin/omac && echo OK`
Expected: prints `OK` with no syntax errors.

- [ ] **Step 3: Run the full suite once more**

Run: `cd ~/Code/omac && zsh test/run.zsh`
Expected: every `test_*.zsh` group passes; overall exit 0.

- [ ] **Step 4: Commit**

```bash
cd ~/Code/omac
git add boot.sh
git commit -m "feat: add boot.sh installer entry point"
```

- [ ] **Step 5: Manual smoke test (on a Mac — do not automate)**

1. From a clean-ish Mac: `OMAC_REPO=<your-fork> zsh boot.sh` (or run `bin/omac install` directly from a clone).
2. Open a new terminal; run `omac doctor` → expect all checks to pass.
3. Run `omac help` → lists `help, version, path, doctor, update, install`.
4. Run `omac update` → pulls, (optionally) bundles, runs migrations, prints `update complete`.

---

## Self-Review Notes

- **Spec coverage:** install locations (Task 2/8), `boot.sh` (Task 9), Homebrew bootstrap (Task 9), zsh dispatcher (Task 3), `help`/`version`/`update`/`doctor`/`path` (Tasks 3,4,6,7), install/core (Task 8), migration engine (Task 5), idempotency (Tasks 8/5 tests), testability via env overrides (every test). All spec sections map to a task.
- **Deferred per spec:** nested `cmd/<command>/<subcommand>` resolution is intentionally not built — no bootstrap command needs it; the module that first needs nesting adds it. `bats` is not adopted; plain zsh assertions suffice.
- **Type/name consistency:** helpers are `omac::info/ok/log/warn/error/require_cmd/confirm/prefix/run/migrate`; env names `OMAC_HOME/OMAC_CONFIG/OMAC_STATE/OMAC_MIGRATIONS_STATE/OMAC_PREFIX/OMAC_YES/OMAC_REPO` — used identically across all tasks.
