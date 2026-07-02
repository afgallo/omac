# omac `software` module — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `omac software` command that installs curated Homebrew packages (per-group Brewfiles) and mise language runtimes, driven by a shared engine that `omac update` also uses.

**Architecture:** A single engine (`lib/software.zsh`) owns all brew/mise logic. Groups are discovered by scanning `software/groups/*.Brewfile` (plus a special `runtimes` group backed by `software/runtimes.manifest`). Three thin command scripts (`cmd/software.zsh`, `cmd/software/install.zsh`, `cmd/software/list.zsh`) and `cmd/update.zsh` all call the engine — no duplicated package logic.

**Tech Stack:** zsh, Homebrew (`brew bundle`), mise (`mise use -g`). Tests are plain `test_*.zsh` files using the repo's `check`/`contains`/`finish` helper with stubbed `brew`/`mise` binaries on `PATH`.

## Global Constraints

- **Shell:** zsh only. Command scripts are **sourced** inside the `omac::run` function scope, so `local` and `return` work (never `exit`, never assume a subshell).
- **Platform:** macOS, Apple Silicon; Homebrew prefix `/opt/homebrew`. Do not hardcode paths — derive via existing helpers.
- **Logging:** use `omac::info` / `omac::ok` / `omac::log` / `omac::warn` / `omac::error` from `lib/common.zsh`. Never `echo`; use `print -r --`.
- **zsh gotcha:** never name a local `path` — `$path` is tied to `$PATH`. (See `lib/common.zsh:56`.)
- **Naming:** engine functions are namespaced `omac::software::<verb>`. Command files carry a `# help: <desc>` first line.
- **No network in tests:** stub `brew` and `mise`; never invoke the real ones.
- **Idempotency:** lean on `brew bundle` and `mise use` being idempotent; add no state files.
- **Env override:** the engine reads its manifests from `$OMAC_SOFTWARE` (default `$OMAC_HOME/software`) so tests can point at a fixture.

---

### Task 1: `OMAC_SOFTWARE` path override + curated seed manifests

Lands the real data (six group Brewfiles + `runtimes.manifest`) and the path override the engine reads. All Homebrew identifiers here were verified against a live `brew`.

**Files:**
- Modify: `lib/paths.zsh` (add `OMAC_SOFTWARE` after `OMAC_TEMPLATES`, line ~9)
- Create: `software/groups/shell.Brewfile`
- Create: `software/groups/tuis.Brewfile`
- Create: `software/groups/ides.Brewfile`
- Create: `software/groups/ai.Brewfile`
- Create: `software/groups/guis.Brewfile`
- Create: `software/groups/fonts.Brewfile`
- Create: `software/runtimes.manifest`
- Test: `test/test_software_seed.zsh`

**Interfaces:**
- Consumes: `OMAC_HOME` from `lib/paths.zsh`.
- Produces: `$OMAC_SOFTWARE` (env-overridable, default `$OMAC_HOME/software`); a `software/` tree with `groups/<name>.Brewfile` files and a `runtimes.manifest`.

- [ ] **Step 1: Write the failing test**

Create `test/test_software_seed.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

export OMAC_HOME="$ROOT"
source "$ROOT/lib/paths.zsh"

check "OMAC_SOFTWARE defaults under OMAC_HOME" "$ROOT/software" "$OMAC_SOFTWARE"

for grp in shell tuis ides ai guis fonts; do
  present="$([[ -f "$ROOT/software/groups/$grp.Brewfile" ]] && print yes || print no)"
  check "$grp.Brewfile exists" "yes" "$present"
done

present="$([[ -f "$ROOT/software/runtimes.manifest" ]] && print yes || print no)"
check "runtimes.manifest exists" "yes" "$present"

contains "tuis has pgcli"       "pgcli"        "$(<"$ROOT/software/groups/tuis.Brewfile")"
contains "ai has claude-code"   "claude-code"  "$(<"$ROOT/software/groups/ai.Brewfile")"
contains "ai has opencode"      "opencode"     "$(<"$ROOT/software/groups/ai.Brewfile")"
contains "guis has ghostty"     "ghostty"      "$(<"$ROOT/software/groups/guis.Brewfile")"
contains "guis has lastpass"    "lastpass"     "$(<"$ROOT/software/groups/guis.Brewfile")"
contains "guis has aerospace"   "nikitabobko/tap/aerospace" "$(<"$ROOT/software/groups/guis.Brewfile")"
contains "guis has sketchybar"  "FelixKratz/formulae/sketchybar" "$(<"$ROOT/software/groups/guis.Brewfile")"
contains "runtimes node lts"    "node@lts"     "$(<"$ROOT/software/runtimes.manifest")"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_software_seed.zsh`
Expected: FAIL — `OMAC_SOFTWARE` is unset (check shows expected `.../software`, actual empty) and files are missing.

- [ ] **Step 3: Add the path override**

In `lib/paths.zsh`, immediately after the `OMAC_TEMPLATES` line, add:

```zsh
: ${OMAC_SOFTWARE:="$OMAC_HOME/software"}
```

- [ ] **Step 4: Create the group Brewfiles and runtimes manifest**

`software/groups/shell.Brewfile`:

```ruby
# Shell tools — the daily-driver CLI layer.
brew "fzf"
brew "zoxide"
brew "ripgrep"
brew "bat"
brew "eza"
brew "fd"
brew "git-delta"
brew "starship"
```

`software/groups/tuis.Brewfile`:

```ruby
# Terminal UIs.
brew "lazygit"
brew "lazydocker"
brew "btop"
brew "pgcli"
```

`software/groups/ides.Brewfile`:

```ruby
# Editors / IDEs.
cask "visual-studio-code"
cask "cursor"
cask "zed"
```

`software/groups/ai.Brewfile`:

```ruby
# AI coding tools.
brew "claude-code"
brew "opencode"
cask "lm-studio"
```

`software/groups/guis.Brewfile`:

```ruby
# User apps.
cask "obsidian"
cask "lastpass"
cask "typora"
cask "localsend"
cask "mpv"
cask "pixelmator-pro"

# Desktop environment — installed here; configured by the wm/launcher/theme modules.
cask "ghostty"                                  # canonical / default terminal
cask "raycast"
tap  "nikitabobko/tap"
cask "nikitabobko/tap/aerospace"
tap  "FelixKratz/formulae"
brew "FelixKratz/formulae/sketchybar"
```

`software/groups/fonts.Brewfile`:

```ruby
# Nerd Fonts (programming font set).
cask "font-jetbrains-mono-nerd-font"
cask "font-fira-code-nerd-font"
cask "font-hack-nerd-font"
cask "font-caskaydia-cove-nerd-font"
```

`software/runtimes.manifest`:

```
# mise-managed global runtimes — one tool spec per line. Blank lines and # comments ignored.
node@lts
python@3.13
go@1.24
ruby@3.4
bun@latest
deno@latest
```

- [ ] **Step 5: Run test to verify it passes**

Run: `zsh test/test_software_seed.zsh`
Expected: PASS — final line `--- N passed, 0 failed ---`.

- [ ] **Step 6: Commit**

```bash
git add lib/paths.zsh software/ test/test_software_seed.zsh
git commit -m "feat(software): add OMAC_SOFTWARE path and curated seed manifests"
```

---

### Task 2: Engine — group discovery (`groups`, `group_file`, `is_group`)

**Files:**
- Create: `lib/software.zsh`
- Test: `test/test_software_groups.zsh`

**Interfaces:**
- Consumes: `$OMAC_SOFTWARE`; logging helpers from `lib/common.zsh`.
- Produces:
  - `omac::software::groups` → prints group names one per line: every `$OMAC_SOFTWARE/groups/*.Brewfile` basename (extension stripped), followed by the literal `runtimes`.
  - `omac::software::group_file <group>` → prints `$OMAC_SOFTWARE/groups/<group>.Brewfile` (no existence check).
  - `omac::software::is_group <group>` → returns 0 if `<group>` is in `groups`, else 1.

- [ ] **Step 1: Write the failing test**

Create `test/test_software_groups.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/lib/common.zsh"

# Fixture manifests dir (isolated from the repo's real software/).
export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
print -r -- 'cask "zed"'     > "$OMAC_SOFTWARE/groups/ides.Brewfile"

source "$ROOT/lib/software.zsh"

groups_out="$(omac::software::groups)"
contains "groups lists shell"     "shell"    "$groups_out"
contains "groups lists ides"      "ides"     "$groups_out"
contains "groups lists runtimes"  "runtimes" "$groups_out"

check "group_file builds path" "$OMAC_SOFTWARE/groups/shell.Brewfile" "$(omac::software::group_file shell)"

omac::software::is_group shell   ; check "is_group shell true"    "0" "$?"
omac::software::is_group runtimes; check "is_group runtimes true" "0" "$?"
omac::software::is_group nope    ; check "is_group nope false"    "1" "$?"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_software_groups.zsh`
Expected: FAIL — `lib/software.zsh` does not exist (source error / functions undefined).

- [ ] **Step 3: Write minimal implementation**

Create `lib/software.zsh`:

```zsh
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_software_groups.zsh`
Expected: PASS — `--- N passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/software.zsh test/test_software_groups.zsh
git commit -m "feat(software): add engine group discovery"
```

---

### Task 3: Engine — install drivers (`install_group`, `install_runtimes`) + test stubs

**Files:**
- Modify: `lib/software.zsh` (append two functions)
- Create: `test/software_stubs.zsh` (shared stub helper reused by Tasks 4–6)
- Test: `test/test_software_install.zsh`

**Interfaces:**
- Consumes: `omac::software::group_file`; `omac::require_cmd` (from `lib/common.zsh`); `$OMAC_SOFTWARE`.
- Produces:
  - `omac::software::install_group <group>` → if `<group>` is `runtimes`, delegates to `install_runtimes`; else runs `brew bundle --file="$(group_file <group>)"`. Errors (return 1) if the Brewfile is missing or `brew` is absent. Returns the underlying command's status.
  - `omac::software::install_runtimes` → ensures `mise` is present (`brew install mise` if missing), parses `$OMAC_SOFTWARE/runtimes.manifest` (ignoring blank/`#` lines, one tool token per line), and runs a single `mise use -g <tool>...`. Returns 0 on an absent/empty manifest.
  - `test/software_stubs.zsh` exposes `_stub_setup` which puts logging `brew` and `mise` fakes on `PATH` and exports `$BREW_LOG` / `$MISE_LOG`. Behavior knobs: `BREW_RC` unused here; `BREW_CHECK_RC` (default 0) for `brew bundle check`; any argument containing `broken` makes `brew` exit 1.

- [ ] **Step 1: Write the shared stub helper**

Create `test/software_stubs.zsh`:

```zsh
# Shared test stubs: fake `brew` and `mise` on PATH that log their args to files.
# Call _stub_setup AFTER exporting OMAC_* env. Exposes $BREW_LOG and $MISE_LOG.
_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export BREW_LOG="$(mktemp)" MISE_LOG="$(mktemp)"
  cat > "$dir/brew" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$BREW_LOG"
[[ "$1" == "bundle" && "$2" == "check" ]] && exit "${BREW_CHECK_RC:-0}"
case "$*" in *broken*) exit 1 ;; esac
exit 0
SH
  cat > "$dir/mise" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$MISE_LOG"
exit 0
SH
  chmod +x "$dir/brew" "$dir/mise"
  export PATH="$dir:$PATH"
}
```

- [ ] **Step 2: Write the failing test**

Create `test/test_software_install.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/software_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
cat > "$OMAC_SOFTWARE/runtimes.manifest" <<'EOF'
# comment line
node@lts
python@3.13
EOF

_stub_setup
source "$ROOT/lib/software.zsh"

omac::software::install_group shell >/dev/null 2>&1
check "install_group shell exits 0" "0" "$?"
contains "brew bundle ran on shell Brewfile" "bundle --file=$OMAC_SOFTWARE/groups/shell.Brewfile" "$(<"$BREW_LOG")"

omac::software::install_group nope >/dev/null 2>&1
check "install_group unknown exits 1" "1" "$?"

omac::software::install_runtimes >/dev/null 2>&1
check "install_runtimes exits 0" "0" "$?"
mise_out="$(<"$MISE_LOG")"
contains "mise use -g invoked" "use -g" "$mise_out"
contains "mise got node@lts"   "node@lts" "$mise_out"
contains "mise got python"     "python@3.13" "$mise_out"
contains "mise skipped comment" "use -g node@lts python@3.13" "$mise_out"
finish
```

- [ ] **Step 3: Run test to verify it fails**

Run: `zsh test/test_software_install.zsh`
Expected: FAIL — `install_group` / `install_runtimes` undefined.

- [ ] **Step 4: Append the implementation**

Append to `lib/software.zsh`:

```zsh
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `zsh test/test_software_install.zsh`
Expected: PASS — `--- N passed, 0 failed ---`.

- [ ] **Step 6: Commit**

```bash
git add lib/software.zsh test/software_stubs.zsh test/test_software_install.zsh
git commit -m "feat(software): add brew/mise install drivers"
```

---

### Task 4: Engine — `install_all` (continue-on-failure + summary)

**Files:**
- Modify: `lib/software.zsh` (append one function)
- Test: `test/test_software_install_all.zsh`

**Interfaces:**
- Consumes: `omac::software::groups`, `omac::software::install_group`, `omac::require_cmd`.
- Produces: `omac::software::install_all` → iterates every group; runs `install_group` on each; **continues past a failing group**; prints a summary; returns 1 if any group failed, else 0.

- [ ] **Step 1: Write the failing test**

Create `test/test_software_install_all.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/software_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
# The stub `brew` exits 1 whenever its args contain "broken" — simulates one bad group.
print -r -- 'cask "whatever"' > "$OMAC_SOFTWARE/groups/broken.Brewfile"
print -r -- 'node@lts'         > "$OMAC_SOFTWARE/runtimes.manifest"

_stub_setup
source "$ROOT/lib/software.zsh"

out="$(omac::software::install_all 2>&1)"
rc="$?"
check "install_all reports failure rc" "1" "$rc"
contains "summary names failed group" "broken" "$out"

log="$(<"$BREW_LOG")"
contains "shell group still installed (continued)" "shell.Brewfile" "$log"
contains "broken group was attempted"              "broken.Brewfile" "$log"
contains "runtimes still ran after failure"        "use -g" "$(<"$MISE_LOG")"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_software_install_all.zsh`
Expected: FAIL — `install_all` undefined.

- [ ] **Step 3: Append the implementation**

Append to `lib/software.zsh`:

```zsh
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_software_install_all.zsh`
Expected: PASS — `--- N passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/software.zsh test/test_software_install_all.zsh
git commit -m "feat(software): add install_all with continue-on-failure"
```

---

### Task 5: Engine — `group_status` (for `list`)

**Files:**
- Modify: `lib/software.zsh` (append one function)
- Test: `test/test_software_status.zsh`

**Interfaces:**
- Consumes: `omac::software::group_file`; `brew bundle check`; `mise` presence.
- Produces: `omac::software::group_status <group>` → prints `satisfied` or `missing`. Non-mutating. For `runtimes`: `satisfied` iff `mise` is on `PATH`. For a Brewfile group: `satisfied` iff `brew` is present and `brew bundle check --file=<file>` exits 0.

- [ ] **Step 1: Write the failing test**

Create `test/test_software_status.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/software_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"

_stub_setup
source "$ROOT/lib/software.zsh"

BREW_CHECK_RC=0 check "satisfied when bundle check passes" "satisfied" "$(BREW_CHECK_RC=0 omac::software::group_status shell)"
check "missing when bundle check fails"   "missing"   "$(BREW_CHECK_RC=1 omac::software::group_status shell)"
check "runtimes satisfied when mise present" "satisfied" "$(omac::software::group_status runtimes)"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_software_status.zsh`
Expected: FAIL — `group_status` undefined.

- [ ] **Step 3: Append the implementation**

Append to `lib/software.zsh`:

```zsh
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_software_status.zsh`
Expected: PASS — `--- N passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/software.zsh test/test_software_status.zsh
git commit -m "feat(software): add group_status for list"
```

---

### Task 6: CLI — `omac software` usage, `install`, `list`

**Files:**
- Create: `cmd/software.zsh` (bare `omac software` → usage)
- Create: `cmd/software/install.zsh`
- Create: `cmd/software/list.zsh`
- Test: `test/test_software_cli.zsh`

**Interfaces:**
- Consumes: the whole engine (`omac::software::*`); the dispatcher in `bin/omac` (resolves `cmd/software/<sub>.zsh` at depth 2, else falls to `cmd/software.zsh`).
- Produces: user-facing commands:
  - `omac software` → prints usage + group list, returns 0; with an unknown subcommand token, warns and returns 1.
  - `omac software install` → `install_all`; `omac software install <group>` → validates via `is_group` then `install_group`; unknown group → error listing valid groups, return 1.
  - `omac software list` → prints a `GROUP / STATUS` table.

- [ ] **Step 1: Write the failing test**

Create `test/test_software_cli.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/software_stubs.zsh"

# Minimal fake OMAC_HOME (symlinked lib/bin/cmd) so the dispatcher runs.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"

# Fixture manifests.
export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
print -r -- 'node@lts'        > "$OMAC_SOFTWARE/runtimes.manifest"

_stub_setup

# bare usage
bare="$(zsh "$fake/bin/omac" software)"
contains "bare prints usage"        "Usage" "$bare"
contains "bare lists shell group"   "shell" "$bare"

# unknown subcommand → nonzero
zsh "$fake/bin/omac" software bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

# install one group
zsh "$fake/bin/omac" software install shell >/dev/null 2>&1
check "install shell exits 0" "0" "$?"
contains "install shell ran brew bundle" "shell.Brewfile" "$(<"$BREW_LOG")"

# unknown group → nonzero + lists valid groups
badout="$(zsh "$fake/bin/omac" software install nope 2>&1)"
zsh "$fake/bin/omac" software install nope >/dev/null 2>&1
check "install unknown group exits 1" "1" "$?"
contains "unknown group lists valid" "shell" "$badout"

# install all
zsh "$fake/bin/omac" software install >/dev/null 2>&1
check "install all exits 0" "0" "$?"

# list
listout="$(zsh "$fake/bin/omac" software list)"
contains "list shows shell"     "shell"     "$listout"
contains "list shows runtimes"  "runtimes"  "$listout"
contains "list shows a status"  "satisfied" "$listout"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_software_cli.zsh`
Expected: FAIL — `omac software` is an unknown command (no `cmd/software.zsh` yet).

- [ ] **Step 3: Create `cmd/software.zsh`**

```zsh
# help: install curated software groups (brew + mise)
source "$OMAC_HOME/lib/software.zsh"
print -r -- "omac software — install curated software"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac software install [group]   install all groups, or one"
print -r -- "  omac software list              list groups and their status"
print -r -- ""
print -r -- "Groups:"
local g
for g in $(omac::software::groups); do
  print -r -- "  $g"
done
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
```

- [ ] **Step 4: Create `cmd/software/install.zsh`**

```zsh
# help: install software groups (all, or one named group)
source "$OMAC_HOME/lib/software.zsh"
local group="${1:-}"
if [[ -z "$group" ]]; then
  omac::software::install_all
  return $?
fi
if ! omac::software::is_group "$group"; then
  omac::error "no such group: $group"
  omac::info "valid groups: $(omac::software::groups | tr '\n' ' ')"
  return 1
fi
omac::software::install_group "$group"
```

- [ ] **Step 5: Create `cmd/software/list.zsh`**

```zsh
# help: list software groups and their status
source "$OMAC_HOME/lib/software.zsh"
local g status
printf "%-12s %s\n" "GROUP" "STATUS"
for g in $(omac::software::groups); do
  status="$(omac::software::group_status "$g")"
  printf "%-12s %s\n" "$g" "$status"
done
```

- [ ] **Step 6: Run test to verify it passes**

Run: `zsh test/test_software_cli.zsh`
Expected: PASS — `--- N passed, 0 failed ---`.

- [ ] **Step 7: Commit**

```bash
git add cmd/software.zsh cmd/software/install.zsh cmd/software/list.zsh test/test_software_cli.zsh
git commit -m "feat(software): add software CLI (usage, install, list)"
```

---

### Task 7: Reconcile `cmd/update.zsh` with the engine

`update.zsh` currently `brew bundle`s a non-existent root `Brewfile`. Point it at the engine so `omac update` and `omac software install` never drift.

**Files:**
- Modify: `cmd/update.zsh:9-12` (the brew-bundle block)
- Test: `test/test_update.zsh` (extend the existing test)

**Interfaces:**
- Consumes: `omac::software::install_all`.
- Produces: `omac update` installs software via the engine (non-fatal — warns and continues on failure), preserving the existing "update complete" output.

- [ ] **Step 1: Extend the failing test**

In `test/test_update.zsh`, after the existing setup that creates `$fake` and before `out="$(zsh "$fake/bin/omac" update 2>&1)"`, add a stub `brew`/`mise` and a fixture software tree so `update` exercises the engine:

```zsh
source "$ROOT/test/software_stubs.zsh"
export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
print -r -- 'node@lts'        > "$OMAC_SOFTWARE/runtimes.manifest"
_stub_setup
```

Then, after the existing `check "update ran migrations" ...` line, add:

```zsh
contains "update installed software via engine" "shell.Brewfile" "$(<"$BREW_LOG")"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_update.zsh`
Expected: FAIL — `$BREW_LOG` has no `shell.Brewfile` (update still uses the old root-Brewfile block, which finds no file).

- [ ] **Step 3: Rewrite the brew-bundle block in `cmd/update.zsh`**

Replace lines 9–12:

```zsh
if [[ -f "$OMAC_HOME/Brewfile" ]] && command -v brew >/dev/null 2>&1; then
  omac::info "running brew bundle"
  brew bundle --file="$OMAC_HOME/Brewfile" || omac::warn "brew bundle had issues; continuing"
fi
```

with:

```zsh
if command -v brew >/dev/null 2>&1; then
  source "$OMAC_HOME/lib/software.zsh"
  omac::info "installing software"
  omac::software::install_all || omac::warn "some software groups had issues; continuing"
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_update.zsh`
Expected: PASS — `--- N passed, 0 failed ---`.

- [ ] **Step 5: Run the whole suite**

Run: `zsh test/run.zsh`
Expected: every `test_*.zsh` block prints `--- N passed, 0 failed ---` and the runner exits 0.

- [ ] **Step 6: Commit**

```bash
git add cmd/update.zsh test/test_update.zsh
git commit -m "feat(software): drive omac update through the software engine"
```

---

## Self-Review

**Spec coverage:**
- Layout (software/, lib/software.zsh, cmd/software*) → Tasks 1, 2, 6. ✓
- Dispatcher fit (bare vs nested) → Task 6 usage + test. ✓
- Engine functions `groups`/`group_file`/`install_group`/`install_all`/`install_runtimes`/`group_status` → Tasks 2–5. ✓ (`is_group` added as the validation helper the CLI needs.)
- Manifest formats + curated seed (all verified ids, node@lts, pgcli, claude-code/opencode, lastpass, ghostty default, aerospace/sketchybar taps; no sublime/helix/Kiro/1password) → Task 1. ✓
- `update.zsh` reconciliation → Task 7. ✓
- Error handling (missing brew, unknown group, per-group failure/continue, runtimes bootstraps mise, update non-fatal) → Tasks 3,4,6,7. ✓
- Testing with stubbed brew/mise + `OMAC_SOFTWARE` fixture → Tasks 1–7. ✓
- `OMAC_SOFTWARE` env override in `lib/paths.zsh` → Task 1. ✓

**Placeholder scan:** none — every step has concrete code/commands and expected output.

**Type/name consistency:** engine names used identically across tasks — `omac::software::groups`, `group_file`, `is_group`, `install_group`, `install_runtimes`, `install_all`, `group_status`; `_stub_setup`, `$BREW_LOG`, `$MISE_LOG`, `$OMAC_SOFTWARE`, `BREW_CHECK_RC` consistent throughout.
