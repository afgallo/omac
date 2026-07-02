# omac `launcher` Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `launcher` module — a thin, guided first-run activation layer for Raycast that frees ⌘Space from Spotlight and hand-holds the GUI-only Raycast setup steps.

**Architecture:** One namespaced engine (`lib/launcher.zsh`) holds all logic; thin `cmd/launcher/*` scripts dispatch into it, exactly like `wm`/`software`. The module deploys **no config files** (Raycast settings are not file-based), so it has no asset tree and no `OMAC_LAUNCHER` override. The single scriptable action is disabling macOS Spotlight's ⌘Space (symbolic hotkey 64) via `defaults`, applied live with the private `activateSettings -u` binary. Everything else is guided output. Two internal env seams (`OMAC_RAYCAST_APP`, `OMAC_ACTIVATE_SETTINGS`) let tests redirect Raycast detection and the private binary.

**Tech Stack:** zsh, macOS `defaults`, `open`, `pgrep`, the private `activateSettings` binary. Tests use the repo's `test/*.zsh` harness (`check`/`contains`/`finish`) with PATH-prepended stub binaries that log their args.

## Global Constraints

- **Platform:** macOS Apple Silicon only; Homebrew prefix `/opt/homebrew`. (Not exercised by this module, but no assumptions may violate it.)
- **XDG-on-macOS:** derive paths via `${XDG_CONFIG_HOME:-$HOME/.config}` fallbacks; never hardcode `~/Library`.
- **Idempotent & non-destructive:** every action re-runnable; the one system change (freeing ⌘Space) is reversible.
- **No hardcoded usernames/paths** beyond the two fixed Apple system paths (the Raycast app bundle and the `activateSettings` binary), both exposed as overridable seams.
- **Engine/command split:** all logic in `lib/launcher.zsh` namespaced `omac::launcher::<verb>`; `cmd/launcher/*` scripts stay thin (source engine, call one function).
- **Unknown-subcommand convention:** bare `omac launcher` prints usage (exit 0); an unknown subcommand token warns and returns non-zero (matches `cmd/wm.zsh`).
- **No `bin/omac` changes:** the existing depth-2 resolver already routes `omac launcher <sub>`.
- **Raycast detection:** app-bundle presence (`/Applications/Raycast.app`), never `command -v raycast` (Raycast ships no PATH binary).

---

## File Structure

- `lib/paths.zsh` (modify) — add two internal seams: `OMAC_RAYCAST_APP`, `OMAC_ACTIVATE_SETTINGS`.
- `lib/launcher.zsh` (create) — the engine; all `omac::launcher::*` functions.
- `cmd/launcher.zsh` (create) — bare `omac launcher` usage.
- `cmd/launcher/install.zsh` (create) — `omac launcher install`.
- `cmd/launcher/status.zsh` (create) — `omac launcher status`.
- `cmd/uninstall.zsh` (modify) — call the launcher reversal.
- `test/launcher_stubs.zsh` (create) — shared stubs (`defaults`, `open`, `pgrep`, `activateSettings`).
- `test/test_launcher_core.zsh` (create) — detection helpers.
- `test/test_launcher_hotkey.zsh` (create) — free/restore/apply.
- `test/test_launcher_status.zsh` (create) — status + activate.
- `test/test_launcher_install.zsh` (create) — guard + full flow.
- `test/test_launcher_cli.zsh` (create) — dispatcher end-to-end.
- `test/test_uninstall.zsh` (modify) — stub the new system calls + assert reversal.

---

## Task 1: Foundation — path seams, stub helper, detection engine

**Files:**
- Modify: `lib/paths.zsh` (append two seam defaults after the existing `: ${OMAC_WM:=…}` line)
- Create: `lib/launcher.zsh`
- Create: `test/launcher_stubs.zsh`
- Test: `test/test_launcher_core.zsh`

**Interfaces:**
- Consumes: `omac::info`/`ok`/`warn`/`error`/`log`/`require_cmd` from `lib/common.zsh`.
- Produces:
  - Env seams `OMAC_RAYCAST_APP` (default `/Applications/Raycast.app`), `OMAC_ACTIVATE_SETTINGS` (default the private binary path).
  - `omac::launcher::raycast_present` → return 0 iff `$OMAC_RAYCAST_APP` is a directory.
  - `omac::launcher::spotlight_hotkey_enabled` → return 0 iff Spotlight ⌘Space appears enabled (default assumption when unreadable).
  - Constant `OMAC_SPOTLIGHT_HOTKEY_ID` (=64).
  - Test helper `_launcher_stub_setup` exposing `$DEFAULTS_LOG`, `$OPEN_LOG`, `$PGREP_LOG`, `$ACTIVATE_LOG`, and honoring `$DEFAULTS_READ_OUT` for `defaults read` output.

- [ ] **Step 1: Write the stub helper**

Create `test/launcher_stubs.zsh`:

```zsh
# Shared launcher test stubs: fake system binaries on PATH that log their args.
# Call _launcher_stub_setup AFTER exporting OMAC_* env. Exposes DEFAULTS_LOG,
# OPEN_LOG, PGREP_LOG, ACTIVATE_LOG. The `defaults` stub echoes $DEFAULTS_READ_OUT
# on `defaults read …` so tests can drive the hotkey-state read path. The
# activateSettings stub is invoked by absolute path, so it is exposed via the
# OMAC_ACTIVATE_SETTINGS seam rather than PATH.
_launcher_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export DEFAULTS_LOG="$(mktemp)" OPEN_LOG="$(mktemp)" \
         PGREP_LOG="$(mktemp)" ACTIVATE_LOG="$(mktemp)"
  local name var
  for name in defaults open pgrep; do
    var="${(U)name}_LOG"
    cat > "$dir/$name" <<SH
#!/usr/bin/env zsh
print -r -- "\$*" >> "\$$var"
[[ "\$1" == read ]] && print -r -- "\${DEFAULTS_READ_OUT:-}"
exit 0
SH
    chmod +x "$dir/$name"
  done
  export PATH="$dir:$PATH"
  local act="$dir/activateSettings"
  cat > "$act" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$ACTIVATE_LOG"
exit 0
SH
  chmod +x "$act"
  export OMAC_ACTIVATE_SETTINGS="$act"
}
```

- [ ] **Step 2: Write the failing test**

Create `test/test_launcher_core.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"
export OMAC_ACTIVATE_SETTINGS="/nonexistent/activateSettings"
_launcher_stub_setup

source "$ROOT/lib/launcher.zsh"

# raycast_present: absent then present.
omac::launcher::raycast_present
check "raycast_present false when app missing" "1" "$?"
mkdir -p "$OMAC_RAYCAST_APP"
omac::launcher::raycast_present
check "raycast_present true when app exists" "0" "$?"

# spotlight_hotkey_enabled: empty read → assume enabled (return 0).
export DEFAULTS_READ_OUT=""
omac::launcher::spotlight_hotkey_enabled
check "hotkey assumed enabled when unreadable" "0" "$?"

# spotlight_hotkey_enabled: a dump showing 64 disabled → return 1.
export DEFAULTS_READ_OUT="AppleSymbolicHotKeys = { 64 = { enabled = 0; }; };"
omac::launcher::spotlight_hotkey_enabled
check "hotkey reported disabled from dump" "1" "$?"
finish
```

- [ ] **Step 3: Run test to verify it fails**

Run: `zsh test/test_launcher_core.zsh`
Expected: FAIL — `omac::launcher::raycast_present: command not found` (engine file empty/missing).

- [ ] **Step 4: Add the path seams**

In `lib/paths.zsh`, immediately after the line `: ${OMAC_WM:="$OMAC_HOME/wm"}`, add:

```zsh
# launcher: internal seams (not user-facing). Raycast ships no PATH binary, so we
# detect its app bundle; activateSettings is a fixed private-framework binary.
: ${OMAC_RAYCAST_APP:="/Applications/Raycast.app"}
: ${OMAC_ACTIVATE_SETTINGS:="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"}
```

- [ ] **Step 5: Write the engine detection helpers**

Create `lib/launcher.zsh`:

```zsh
# The launcher engine: guided first-run activation for Raycast. Sourced by
# cmd/launcher/* so all logic lives here. Pure activation layer — `software`
# installs the Raycast cask; `theme` owns colors; launcher deploys nothing on disk.
#
# The one scriptable step is freeing macOS Spotlight's ⌘Space (symbolic hotkey
# 64) so Raycast can claim it. Everything else is guided (GUI-only).

# Spotlight owns ⌘Space via symbolic hotkey 64. Set once, idempotent across
# re-sourcing (no `readonly`, which would error on a second source).
: ${OMAC_SPOTLIGHT_HOTKEY_ID:=64}

# True iff Raycast is installed. Raycast ships no PATH binary, so detect the app
# bundle. OMAC_RAYCAST_APP is a test seam (see lib/paths.zsh).
omac::launcher::raycast_present() {
  [[ -d "$OMAC_RAYCAST_APP" ]]
}

# Best-effort: is Spotlight's ⌘Space still enabled? Unreadable/absent → assume
# enabled (the macOS default). Used by status and for idempotency.
omac::launcher::spotlight_hotkey_enabled() {
  local dump
  dump="$(defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys 2>/dev/null)" || return 0
  # If the id-64 dict carries "enabled = 0", the shortcut is disabled; otherwise
  # (including not found) treat it as enabled. Best-effort string match.
  [[ "$dump" != *"$OMAC_SPOTLIGHT_HOTKEY_ID = "*"enabled = 0"* ]]
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `zsh test/test_launcher_core.zsh`
Expected: PASS — all four checks `ok`, `--- 4 passed, 0 failed ---`.

- [ ] **Step 7: Commit**

```bash
git add lib/paths.zsh lib/launcher.zsh test/launcher_stubs.zsh test/test_launcher_core.zsh
git commit -m "feat(launcher): engine foundation — path seams + detection helpers"
```

---

## Task 2: Free / restore the Spotlight hotkey

**Files:**
- Modify: `lib/launcher.zsh` (append three functions)
- Test: `test/test_launcher_hotkey.zsh`

**Interfaces:**
- Consumes: `omac::launcher::spotlight_hotkey_enabled`, `OMAC_SPOTLIGHT_HOTKEY_ID`, `OMAC_ACTIVATE_SETTINGS`, `omac::require_cmd`.
- Produces:
  - `omac::launcher::apply_hotkey_settings` → run `$OMAC_ACTIVATE_SETTINGS -u` if executable, else warn (non-fatal).
  - `omac::launcher::free_spotlight_hotkey` → disable hotkey 64 (no-op if already disabled), then apply.
  - `omac::launcher::restore_spotlight_hotkey` → re-enable hotkey 64 (no-op if already enabled), then apply.

- [ ] **Step 1: Write the failing test**

Create `test/test_launcher_hotkey.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

_launcher_stub_setup
source "$ROOT/lib/launcher.zsh"

# From the default (enabled) state, free_spotlight_hotkey writes disable + applies.
export DEFAULTS_READ_OUT=""
omac::launcher::free_spotlight_hotkey >/dev/null 2>&1
check "free exits 0" "0" "$?"
contains "free wrote symbolichotkeys" "write com.apple.symbolichotkeys" "$(<"$DEFAULTS_LOG")"
contains "free targeted hotkey 64"    "64"          "$(<"$DEFAULTS_LOG")"
contains "free set enabled = 0"       "enabled = 0" "$(<"$DEFAULTS_LOG")"
contains "free applied live"          "-u"          "$(<"$ACTIVATE_LOG")"

# Idempotency: when already disabled, free writes nothing.
: > "$DEFAULTS_LOG"
export DEFAULTS_READ_OUT="AppleSymbolicHotKeys = { 64 = { enabled = 0; }; };"
omac::launcher::free_spotlight_hotkey >/dev/null 2>&1
wrote="$([[ "$(<"$DEFAULTS_LOG")" == *write* ]] && print yes || print no)"
check "free is a no-op when already freed" "no" "$wrote"

# restore re-enables from the disabled state.
: > "$DEFAULTS_LOG"
omac::launcher::restore_spotlight_hotkey >/dev/null 2>&1
contains "restore set enabled = 1" "enabled = 1" "$(<"$DEFAULTS_LOG")"

# apply_hotkey_settings degrades gracefully when activateSettings is absent.
: > "$ACTIVATE_LOG"
export OMAC_ACTIVATE_SETTINGS="/nonexistent/activateSettings"
out="$(omac::launcher::apply_hotkey_settings 2>&1)"
check "apply exits 0 without the binary" "0" "$?"
contains "apply prints re-login hint" "log out" "$out"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_launcher_hotkey.zsh`
Expected: FAIL — `omac::launcher::free_spotlight_hotkey: command not found`.

- [ ] **Step 3: Append the implementation**

Append to `lib/launcher.zsh`:

```zsh
# Apply symbolic-hotkey changes live. OMAC_ACTIVATE_SETTINGS is the private
# binary (test seam); if it is missing, fall back to a re-login hint (non-fatal).
omac::launcher::apply_hotkey_settings() {
  if [[ -x "$OMAC_ACTIVATE_SETTINGS" ]]; then
    "$OMAC_ACTIVATE_SETTINGS" -u
  else
    omac::warn "log out and back in for the ⌘Space change to take effect"
  fi
}

# Disable Spotlight's ⌘Space so Raycast can bind it. Idempotent — a no-op if
# already freed. The dict preserves the binding definition and only flips enabled.
omac::launcher::free_spotlight_hotkey() {
  omac::require_cmd defaults || return 1
  if ! omac::launcher::spotlight_hotkey_enabled; then
    omac::ok "Spotlight ⌘Space already freed"
    return 0
  fi
  omac::info "freeing ⌘Space from Spotlight"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
    "$OMAC_SPOTLIGHT_HOTKEY_ID" \
    '{ enabled = 0; value = { parameters = ( 65535, 49, 1048576 ); type = standard; }; }'
  omac::launcher::apply_hotkey_settings
}

# Re-enable Spotlight's ⌘Space — the clean inverse used by uninstall. No-op if
# already enabled (so a plain uninstall that never freed it does nothing).
omac::launcher::restore_spotlight_hotkey() {
  omac::require_cmd defaults || return 1
  if omac::launcher::spotlight_hotkey_enabled; then
    return 0
  fi
  omac::info "restoring Spotlight ⌘Space"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
    "$OMAC_SPOTLIGHT_HOTKEY_ID" \
    '{ enabled = 1; value = { parameters = ( 65535, 49, 1048576 ); type = standard; }; }'
  omac::launcher::apply_hotkey_settings
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_launcher_hotkey.zsh`
Expected: PASS — `--- 8 passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/launcher.zsh test/test_launcher_hotkey.zsh
git commit -m "feat(launcher): free/restore Spotlight ⌘Space, applied live"
```

---

## Task 3: Activation output and status

**Files:**
- Modify: `lib/launcher.zsh` (append two functions)
- Test: `test/test_launcher_status.zsh`

**Interfaces:**
- Consumes: `omac::launcher::raycast_present`, `omac::launcher::spotlight_hotkey_enabled`, `open`, `pgrep`.
- Produces:
  - `omac::launcher::activate` → `open -a Raycast`, open the Keyboard and Accessibility panes, print the 3 manual steps.
  - `omac::launcher::status` → print Raycast installed / running / ⌘Space freed; performs no writes.

- [ ] **Step 1: Write the failing test**

Create `test/test_launcher_status.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"; mkdir -p "$OMAC_RAYCAST_APP"
_launcher_stub_setup
source "$ROOT/lib/launcher.zsh"

# activate opens Raycast and the panes, and prints the manual checklist.
out="$(omac::launcher::activate 2>&1)"
contains "activate opened Raycast"        "Raycast"              "$(<"$OPEN_LOG")"
contains "activate opened Accessibility"  "Privacy_Accessibility" "$(<"$OPEN_LOG")"
contains "activate lists manual steps"    "Clipboard History"    "$out"

# status reports the three facts and performs no writes.
export DEFAULTS_READ_OUT=""
: > "$DEFAULTS_LOG"
out="$(omac::launcher::status)"
contains "status shows Raycast installed" "Raycast installed" "$out"
contains "status shows running row"       "Raycast running"   "$out"
contains "status shows hotkey row"        "⌘Space freed"      "$out"
wrote="$([[ "$(<"$DEFAULTS_LOG")" == *write* ]] && print yes || print no)"
check "status performs no defaults write" "no" "$wrote"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_launcher_status.zsh`
Expected: FAIL — `omac::launcher::activate: command not found`.

- [ ] **Step 3: Append the implementation**

Append to `lib/launcher.zsh`:

```zsh
# Guided activation: open Raycast and the settings panes, then print the manual
# steps macOS/Raycast forbid scripting.
omac::launcher::activate() {
  omac::info "opening Raycast"
  open -a Raycast
  omac::info "opening the settings panes to finish setup"
  open "x-apple.systempreferences:com.apple.preference.keyboard"
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  omac::info "manual steps (GUI-only):"
  omac::log "1. In Raycast, set the launcher hotkey to ⌘Space."
  omac::log "2. In Raycast, enable Clipboard History (and give it a hotkey)."
  omac::log "3. Grant Raycast Accessibility in System Settings > Privacy."
  omac::ok "launcher activated (finish the 3 manual steps above)"
}

# Non-mutating status: is Raycast installed / running, and is ⌘Space freed?
omac::launcher::status() {
  local inst run freed
  omac::launcher::raycast_present && inst=yes || inst=no
  pgrep -x Raycast >/dev/null 2>&1 && run=yes || run=no
  omac::launcher::spotlight_hotkey_enabled && freed=no || freed=yes
  printf "%-20s %s\n" "Raycast installed:" "$inst"
  printf "%-20s %s\n" "Raycast running:"   "$run"
  printf "%-20s %s\n" "⌘Space freed:"      "$freed"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_launcher_status.zsh`
Expected: PASS — `--- 7 passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/launcher.zsh test/test_launcher_status.zsh
git commit -m "feat(launcher): guided activation output + non-mutating status"
```

---

## Task 4: Install orchestration

**Files:**
- Modify: `lib/launcher.zsh` (append one function)
- Test: `test/test_launcher_install.zsh`

**Interfaces:**
- Consumes: `omac::launcher::raycast_present`, `omac::launcher::free_spotlight_hotkey`, `omac::launcher::activate`.
- Produces: `omac::launcher::install` → guard Raycast present (else error → `omac software install`), free ⌘Space, activate.

- [ ] **Step 1: Write the failing test**

Create `test/test_launcher_install.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
source "$ROOT/lib/common.zsh"

# Guard first: no Raycast app -> hard error hinting software install.
export OMAC_RAYCAST_APP="/nonexistent/Raycast.app"
_launcher_stub_setup
source "$ROOT/lib/launcher.zsh"

omac::launcher::install >/dev/null 2>&1
check "install without Raycast exits 1" "1" "$?"
hint="$(omac::launcher::install 2>&1)"
contains "guard hints software install" "software install" "$hint"

# Now with Raycast present -> full flow runs.
export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"; mkdir -p "$OMAC_RAYCAST_APP"
export DEFAULTS_READ_OUT=""
: > "$DEFAULTS_LOG"; : > "$OPEN_LOG"; : > "$ACTIVATE_LOG"
omac::launcher::install >/dev/null 2>&1
check "install exits 0" "0" "$?"
contains "install freed ⌘Space"   "write com.apple.symbolichotkeys" "$(<"$DEFAULTS_LOG")"
contains "install applied live"   "-u"      "$(<"$ACTIVATE_LOG")"
contains "install opened Raycast" "Raycast" "$(<"$OPEN_LOG")"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_launcher_install.zsh`
Expected: FAIL — `omac::launcher::install: command not found`.

- [ ] **Step 3: Append the implementation**

Append to `lib/launcher.zsh`:

```zsh
# Orchestrate the guided first-run: guard Raycast installed, free ⌘Space, then
# run guided activation.
omac::launcher::install() {
  if ! omac::launcher::raycast_present; then
    omac::error "Raycast must be installed first"
    omac::info "run: omac software install"
    return 1
  fi
  omac::launcher::free_spotlight_hotkey
  omac::launcher::activate
  omac::ok "launcher installed"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_launcher_install.zsh`
Expected: PASS — `--- 6 passed, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add lib/launcher.zsh test/test_launcher_install.zsh
git commit -m "feat(launcher): install orchestration (guard + free + activate)"
```

---

## Task 5: CLI wiring

**Files:**
- Create: `cmd/launcher.zsh`
- Create: `cmd/launcher/install.zsh`
- Create: `cmd/launcher/status.zsh`
- Test: `test/test_launcher_cli.zsh`

**Interfaces:**
- Consumes: the dispatcher in `bin/omac` (depth-2 resolver, no changes), `omac::launcher::install`, `omac::launcher::status`.
- Produces: `omac launcher` (usage), `omac launcher install`, `omac launcher status` end-to-end commands.

- [ ] **Step 1: Write the failing test**

Create `test/test_launcher_cli.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"

# Minimal fake OMAC_HOME (symlinked lib/bin/cmd) so the dispatcher runs.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export HOME="$(mktemp -d)"
export OMAC_RAYCAST_APP="$(mktemp -d)/Raycast.app"; mkdir -p "$OMAC_RAYCAST_APP"
export DEFAULTS_READ_OUT=""
_launcher_stub_setup

# bare usage
bare="$(zsh "$fake/bin/omac" launcher)"
contains "bare prints usage"     "Usage"   "$bare"
contains "bare mentions install" "install" "$bare"

# unknown subcommand -> nonzero
zsh "$fake/bin/omac" launcher bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

# install
zsh "$fake/bin/omac" launcher install >/dev/null 2>&1
check "cli install exits 0" "0" "$?"
contains "cli install freed ⌘Space" "write com.apple.symbolichotkeys" "$(<"$DEFAULTS_LOG")"

# status
out="$(zsh "$fake/bin/omac" launcher status)"
contains "cli status shows Raycast row" "Raycast installed" "$out"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_launcher_cli.zsh`
Expected: FAIL — bare `omac launcher` falls through to the unknown-command help (no `cmd/launcher.zsh`), so "Usage" is absent.

- [ ] **Step 3: Write the bare usage command**

Create `cmd/launcher.zsh`:

```zsh
# help: guide Raycast first-run (free ⌘Space, hand-hold the GUI-only steps)
source "$OMAC_HOME/lib/launcher.zsh"
print -r -- "omac launcher — set up Raycast as the keyboard launcher"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac launcher install   free ⌘Space + guided Raycast first-run"
print -r -- "  omac launcher status    show Raycast install/run state and ⌘Space"
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
```

- [ ] **Step 4: Write the install command**

Create `cmd/launcher/install.zsh`:

```zsh
# help: free ⌘Space and run the guided Raycast first-run
source "$OMAC_HOME/lib/launcher.zsh"
omac::launcher::install
```

- [ ] **Step 5: Write the status command**

Create `cmd/launcher/status.zsh`:

```zsh
# help: show Raycast install/run state and whether ⌘Space is freed
source "$OMAC_HOME/lib/launcher.zsh"
omac::launcher::status
```

- [ ] **Step 6: Run test to verify it passes**

Run: `zsh test/test_launcher_cli.zsh`
Expected: PASS — `--- 5 passed, 0 failed ---`.

- [ ] **Step 7: Commit**

```bash
git add cmd/launcher.zsh cmd/launcher/install.zsh cmd/launcher/status.zsh test/test_launcher_cli.zsh
git commit -m "feat(launcher): CLI — install/status + usage"
```

---

## Task 6: Reversibility wiring in uninstall

**Files:**
- Modify: `cmd/uninstall.zsh` (add the launcher reversal)
- Modify: `test/test_uninstall.zsh` (stub the new system calls, drive the disabled state, assert reversal)

**Interfaces:**
- Consumes: `omac::launcher::restore_spotlight_hotkey`.
- Produces: `omac uninstall` re-enables Spotlight's ⌘Space (no-op when it was never freed).

- [ ] **Step 1: Update the uninstall test first (it must stub the new system calls)**

Replace the whole contents of `test/test_uninstall.zsh` with:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/launcher_stubs.zsh"
export OMAC_HOME="$ROOT"
export OMAC_CONFIG="$(mktemp -d)/omac"
export OMAC_STATE="$(mktemp -d)/omac"
export OMAC_PREFIX="$(mktemp -d)"
export OMAC_PROFILE="$(mktemp -d)/.zprofile"
export OMAC_YES=1   # auto-confirm the config/state deletion

# Stub system calls so uninstall's launcher reversal never touches the real Mac.
# Drive a "disabled" hotkey read so restore actually re-enables (and is asserted).
_launcher_stub_setup
export DEFAULTS_READ_OUT="AppleSymbolicHotKeys = { 64 = { enabled = 0; }; };"

zsh "$ROOT/bin/omac" install >/dev/null 2>&1
zsh "$ROOT/bin/omac" uninstall >/dev/null 2>&1
check "uninstall exits 0" "0" "$?"
check "CLI symlink removed" "1" "$(test ! -e "$OMAC_PREFIX/bin/omac" && print 1 || print 0)"
check "zprofile block removed" "0" "$(grep -c '>>> omac >>>' "$OMAC_PROFILE")"
check "config removed (OMAC_YES)" "1" "$(test ! -d "$OMAC_CONFIG" && print 1 || print 0)"
contains "uninstall restored ⌘Space" "enabled = 1" "$(<"$DEFAULTS_LOG")"
contains "uninstall applied live"    "-u"          "$(<"$ACTIVATE_LOG")"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `zsh test/test_uninstall.zsh`
Expected: FAIL — "uninstall restored ⌘Space (missing substring: [enabled = 1])": `cmd/uninstall.zsh` does not yet call the reversal.

- [ ] **Step 3: Wire the reversal into uninstall**

In `cmd/uninstall.zsh`, immediately after the `omac::remove_block "$OMAC_PROFILE"` / `omac::ok "removed shell integration…"` pair and **before** the `if omac::confirm "Also delete …"` block, insert:

```zsh
# Reverse the one system change launcher makes (re-enable Spotlight ⌘Space).
# No-op if it was never freed; best-effort so a broken env can't block uninstall.
source "$OMAC_HOME/lib/launcher.zsh"
omac::launcher::restore_spotlight_hotkey || omac::warn "could not restore ⌘Space"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `zsh test/test_uninstall.zsh`
Expected: PASS — `--- 6 passed, 0 failed ---`.

- [ ] **Step 5: Run the full suite**

Run: `zsh test/run.zsh`
Expected: every `test_*.zsh` file reports `0 failed`; overall exit 0.

- [ ] **Step 6: Commit**

```bash
git add cmd/uninstall.zsh test/test_uninstall.zsh
git commit -m "feat(launcher): reverse ⌘Space change on uninstall"
```

---

## Self-Review

**1. Spec coverage** (against `2026-07-02-omac-launcher-design.md`):

- Scope = guided Raycast activation, deploys nothing → Tasks 1–5; no asset dir / no `OMAC_LAUNCHER` ✓ (only internal seams added).
- Scriptable: free ⌘Space via `defaults` on hotkey 64 + `activateSettings -u` → Task 2 ✓.
- `activateSettings` fallback hint when binary absent → Task 2 (apply test) ✓.
- Guided steps: open Raycast + panes + checklist → Task 3 ✓.
- Layout `lib/launcher.zsh` + `cmd/launcher.zsh` + `cmd/launcher/{install,status}.zsh`, no `reload` → Task 5 ✓.
- Engine function table (`raycast_present`, `spotlight_hotkey_enabled`, `free_spotlight_hotkey`, `activate`, `status`, `install`, `restore_spotlight_hotkey`) → Tasks 1–4, 6 ✓.
- App-bundle detection, not `command -v` → Task 1 ✓.
- Dispatcher fit, no `bin/omac` change → Task 5 (uses existing resolver) ✓.
- Reversibility via uninstall → Task 6 ✓.
- Error handling: Raycast-missing guard → Task 4; `activateSettings` absent → Task 2; unknown subcommand → Task 5 ✓.
- Testing: stub `defaults`/`open`/`pgrep`/`activateSettings`; guard, install-writes, status-no-writes, restore, bare/bogus CLI → Tasks 1–6 ✓.

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code and exact commands. ✓

**3. Type/name consistency:** Function names identical across tasks (`omac::launcher::free_spotlight_hotkey`, `restore_spotlight_hotkey`, `apply_hotkey_settings`, `raycast_present`, `spotlight_hotkey_enabled`, `activate`, `status`, `install`); env seams `OMAC_RAYCAST_APP` / `OMAC_ACTIVATE_SETTINGS` / `OMAC_SPOTLIGHT_HOTKEY_ID` used consistently; stub log vars (`DEFAULTS_LOG`, `OPEN_LOG`, `PGREP_LOG`, `ACTIVATE_LOG`, `DEFAULTS_READ_OUT`) consistent. ✓
