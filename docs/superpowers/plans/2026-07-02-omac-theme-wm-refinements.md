# omac theme + wm refinements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the scope changes agreed on 2026-07-02 — fix VS Code/Cursor theming to the correct macOS path, add bat + git-delta theming, drop the dead Zed keys, and add a SketchyBar battery plugin.

**Architecture:** Small, additive changes to the existing `lib/theme.zsh` engine (new `apply_bat`/`apply_delta`/`appsupport_dir` functions wired into `omac::theme::set`) plus one new `wm/sketchybar/plugins/battery.sh` and its `sketchybarrc` registration. No new modules, no CLI surface changes. Everything follows the established "thin cmd over one namespaced engine" and `test_*.zsh` stub patterns.

**Tech Stack:** zsh (pure — no python/jq/TOML libs), bash for SketchyBar plugins, macOS `osascript`/`pmset`/`defaults`, `git config`, the existing `omac::remove_block`/`omac::ensure_block`/`omac::install_file` helpers, and the `test/helper.zsh` + `test/theme_stubs.zsh`/`wm_stubs.zsh` harness.

## Global Constraints

- **zsh only** in `lib/`/`cmd/`; **bash** for SketchyBar `plugins/*`. No python, jq, or TOML libraries — parse with grep/sed via the existing `omac::theme::toml_get`.
- **Apple Silicon macOS** only; Homebrew prefix `/opt/homebrew`.
- **Best-effort, never fatal:** a missing binary or missing built-in name warns and skips that one target; only an unknown theme name is a hard error in `set`.
- **Tests never touch real system state:** stub every system binary on a temp `PATH`; redirect every real location through an env override (`OMAC_THEMES`, `XDG_CONFIG_HOME`, `OMAC_CONFIG`, `OMAC_APPSUPPORT`, `HOME`) into `mktemp` dirs.
- **Functions namespaced** `omac::theme::<verb>` / `omac::wm::<verb>`; colors in SketchyBar plugins come from the `colors.sh` seam, never hardcoded.
- **Authoritative spec:** `docs/superpowers/specs/2026-07-02-omac-theme-design.md` (theme) and `…-wm-design.md` (battery).

---

### Task 1: Fix VS Code/Cursor settings path (macOS `Application Support`)

VS Code and Cursor on macOS read `~/Library/Application Support/{Code,Cursor}/User/settings.json`, **not** `~/.config`. `apply_vscode` currently writes under `config_dir()` (XDG), so theme switches silently miss. Introduce an `OMAC_APPSUPPORT` seam and point `apply_vscode` at it.

**Files:**
- Modify: `lib/paths.zsh` (add `OMAC_APPSUPPORT`)
- Modify: `lib/theme.zsh` (add `appsupport_dir`, repoint `apply_vscode`)
- Test: `test/test_theme_apply.zsh` (redirect + assert new path)
- Test: `test/test_theme_set.zsh` (redirect + assert new path)

**Interfaces:**
- Produces: `omac::theme::appsupport_dir()` → prints `$OMAC_APPSUPPORT`. `apply_vscode` writes `<appsupport>/Code/User/settings.json` and `<appsupport>/Cursor/User/settings.json` (Cursor only if `<appsupport>/Cursor` exists).
- Consumes: existing `omac::theme::_vscode_write <colorTheme> <settings-file>`.

- [ ] **Step 1: Update the failing tests to the new path**

In `test/test_theme_apply.zsh`, after the `export HOME=…` line (line 16), add:

```zsh
export OMAC_APPSUPPORT="$(mktemp -d)"
```

and change the VS Code target (line 33) from:

```zsh
vs="$XDG_CONFIG_HOME/Code/User/settings.json"
```

to:

```zsh
vs="$OMAC_APPSUPPORT/Code/User/settings.json"
```

In `test/test_theme_set.zsh`, after the `export HOME=…` line (line 25), add:

```zsh
export OMAC_APPSUPPORT="$(mktemp -d)"
```

and change the VS Code assertion (line 41) from:

```zsh
contains "vscode colorTheme from vscode.json" "Tokyo Night" "$(<"$XDG_CONFIG_HOME/Code/User/settings.json")"
```

to:

```zsh
contains "vscode colorTheme from vscode.json" "Tokyo Night" "$(<"$OMAC_APPSUPPORT/Code/User/settings.json")"
```

- [ ] **Step 2: Run both tests to verify they fail**

Run: `zsh test/test_theme_apply.zsh; zsh test/test_theme_set.zsh`
Expected: FAIL — `apply_vscode` still writes under `$XDG_CONFIG_HOME/Code/...`, so the new `$OMAC_APPSUPPORT/Code/...` file is absent (empty read / missing substring).

- [ ] **Step 3: Add the `OMAC_APPSUPPORT` default**

In `lib/paths.zsh`, immediately after the `OMAC_ACTIVE_THEME` line (line 11), add:

```zsh
: ${OMAC_APPSUPPORT:="$HOME/Library/Application Support"}  # VS Code/Cursor settings root (NOT XDG on macOS)
```

- [ ] **Step 4: Add `appsupport_dir` and repoint `apply_vscode`**

In `lib/theme.zsh`, replace the whole `omac::theme::apply_vscode` function (lines 152–158) with:

```zsh
# VS Code/Cursor settings root. NOT XDG on macOS — they read ~/Library/Application Support.
# One place so tests redirect via OMAC_APPSUPPORT.
omac::theme::appsupport_dir() {
  print -r -- "$OMAC_APPSUPPORT"
}

# Apply the VS Code colorTheme to VS Code and Cursor (whichever config dirs exist).
omac::theme::apply_vscode() {        # <colorTheme>
  local name="$1" as; as="$(omac::theme::appsupport_dir)"
  omac::theme::_vscode_write "$name" "$as/Code/User/settings.json"
  [[ -d "$as/Cursor" ]] && omac::theme::_vscode_write "$name" "$as/Cursor/User/settings.json"
  omac::info "editor theme: $name"
}
```

- [ ] **Step 5: Run both tests to verify they pass**

Run: `zsh test/test_theme_apply.zsh; zsh test/test_theme_set.zsh`
Expected: PASS — each prints `--- N passed, 0 failed ---`.

- [ ] **Step 6: Commit**

```bash
git add lib/paths.zsh lib/theme.zsh test/test_theme_apply.zsh test/test_theme_set.zsh
git commit -m "fix(theme): write VS Code/Cursor settings to macOS Application Support path"
```

---

### Task 2: bat + git-delta theming

bat does not follow the terminal palette; it needs its own theme. delta shares bat's theme namespace, so it reuses the same name. Both are driven by the theme's `apps.toml` `bat` key and are best-effort (skip when the key or the tool is absent).

**Files:**
- Modify: `test/theme_stubs.zsh` (add `bat` + `git` stubs)
- Modify: `lib/theme.zsh` (add `apply_bat`, `apply_delta`; call them from `set`)
- Test: `test/test_theme_batdelta.zsh` (new)

**Interfaces:**
- Consumes: `omac::theme::toml_get <file> <key>`, `omac::theme::config_dir`, `omac::remove_block`/`omac::ensure_block`.
- Produces:
  - `omac::theme::apply_bat <name>` → when `apps.toml` has a `bat` name and the `bat` CLI is present, writes an omac-managed block `--theme="<name>"` into `<config_dir>/bat/config`; otherwise no-op (returns 0).
  - `omac::theme::apply_delta <name>` → when `apps.toml` has a `bat` name and `git` is present, runs `git config --global delta.syntax-theme "<name>"`; otherwise no-op (returns 0).
  - `omac::theme::set` calls both after `apply_vscode`.

- [ ] **Step 1: Add `bat` and `git` stubs to the theme harness**

In `test/theme_stubs.zsh`, extend the log exports and the stub loop. Replace lines 7–10:

```zsh
  export OSASCRIPT_LOG="$(mktemp)" CODE_LOG="$(mktemp)" CURSOR_LOG="$(mktemp)" \
         SKETCHYBAR_LOG="$(mktemp)" DEFAULTS_LOG="$(mktemp)" OPEN_LOG="$(mktemp)"
  local name var
  for name in osascript code cursor sketchybar defaults open; do
```

with:

```zsh
  export OSASCRIPT_LOG="$(mktemp)" CODE_LOG="$(mktemp)" CURSOR_LOG="$(mktemp)" \
         SKETCHYBAR_LOG="$(mktemp)" DEFAULTS_LOG="$(mktemp)" OPEN_LOG="$(mktemp)" \
         BAT_LOG="$(mktemp)" GIT_LOG="$(mktemp)"
  local name var
  for name in osascript code cursor sketchybar defaults open bat git; do
```

(Also update the header comment on line 3–4 to list `BAT_LOG`, `GIT_LOG`.)

- [ ] **Step 2: Write the failing test**

Create `test/test_theme_batdelta.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_THEMES="$(mktemp -d)/themes"
# Theme WITH a bat name.
mkdir -p "$OMAC_THEMES/named"
print -r -- 'ghostty = "tokyonight"' >  "$OMAC_THEMES/named/apps.toml"
print -r -- 'bat = "TwoDark"'         >> "$OMAC_THEMES/named/apps.toml"
# Theme WITHOUT a bat name.
mkdir -p "$OMAC_THEMES/plain"
print -r -- 'ghostty = "x"' > "$OMAC_THEMES/plain/apps.toml"

export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
_theme_stub_setup
source "$ROOT/lib/theme.zsh"
batcfg="$XDG_CONFIG_HOME/bat/config"

# No bat name -> neither target is touched (checked first, before any file exists).
omac::theme::apply_bat plain >/dev/null 2>&1
omac::theme::apply_delta plain >/dev/null 2>&1
check "no bat config for unnamed theme" "no" "$([[ -f "$batcfg" ]] && print yes || print no)"
check "delta untouched for unnamed theme" "" "$(<"$GIT_LOG")"

# bat: named theme writes a managed --theme block.
omac::theme::apply_bat named >/dev/null 2>&1
contains "bat config has theme" '--theme="TwoDark"' "$(<"$batcfg")"

# delta: named theme calls git config with the same name.
omac::theme::apply_delta named >/dev/null 2>&1
contains "delta syntax-theme set" 'config --global delta.syntax-theme TwoDark' "$(<"$GIT_LOG")"

# Re-applying replaces (no duplicate --theme line).
omac::theme::apply_bat named >/dev/null 2>&1
check "bat theme single line after re-apply" "1" "$(grep -c -- '--theme=' "$batcfg")"
finish
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `zsh test/test_theme_batdelta.zsh`
Expected: FAIL — `omac::theme::apply_bat`/`apply_delta` are undefined (`command not found`), so assertions miss.

- [ ] **Step 4: Implement `apply_bat` and `apply_delta`**

In `lib/theme.zsh`, insert these two functions immediately after `omac::theme::apply_vscode` (after line 158 in the current file, i.e. right before the `# --- Orchestration ---` banner):

```zsh
# bat: write a managed --theme block into ~/.config/bat/config when the theme
# names a bat built-in; no-op otherwise. Best-effort (needs the `bat` CLI).
omac::theme::apply_bat() {           # <name>
  local theme; theme="$(omac::theme::toml_get "$OMAC_THEMES/$1/apps.toml" bat)" || return 0
  [[ -n "$theme" ]] || return 0
  if ! command -v bat >/dev/null 2>&1; then
    omac::warn "no 'bat' — skipping bat theme"; return 0
  fi
  local f; f="$(omac::theme::config_dir)/bat/config"
  mkdir -p "${f:h}"
  omac::remove_block "$f"
  omac::ensure_block "$f" "--theme=\"$theme\""
  omac::info "bat theme: $theme"
}

# git-delta: reuse the theme's bat name as delta's syntax-theme (shared
# namespace). No-op when unnamed; best-effort (needs `git`).
omac::theme::apply_delta() {         # <name>
  local theme; theme="$(omac::theme::toml_get "$OMAC_THEMES/$1/apps.toml" bat)" || return 0
  [[ -n "$theme" ]] || return 0
  if ! command -v git >/dev/null 2>&1; then
    omac::warn "no 'git' — skipping delta theme"; return 0
  fi
  git config --global delta.syntax-theme "$theme" 2>/dev/null \
    || omac::warn "could not set delta syntax-theme"
  omac::info "delta syntax-theme: $theme"
}
```

- [ ] **Step 5: Wire both into `omac::theme::set`**

In `lib/theme.zsh`, in `omac::theme::set`, immediately after the VS Code block (after the `[[ -n "$ct" ]] && omac::theme::apply_vscode "$ct"` line), add:

```zsh
  # 3b. bat + git-delta (best-effort): both driven by the apps.toml `bat` name.
  omac::theme::apply_bat "$name"
  omac::theme::apply_delta "$name"
```

- [ ] **Step 6: Run the new test and the full-switch test**

Run: `zsh test/test_theme_batdelta.zsh; zsh test/test_theme_set.zsh`
Expected: PASS both — `test_theme_set` still passes because its `tokyo-night` fixture has no `bat` key, so `apply_bat`/`apply_delta` no-op.

- [ ] **Step 7: Commit**

```bash
git add lib/theme.zsh test/theme_stubs.zsh test/test_theme_batdelta.zsh
git commit -m "feat(theme): theme bat and git-delta from the apps.toml bat name"
```

---

### Task 3: Remove dead `zed` keys from every `apps.toml`

Zed is out of scope (no OOB coverage, no install CLI). The `zed = "…"` lines in `themes/*/apps.toml` are never read — delete them so the config matches the spec.

**Files:**
- Modify: `themes/*/apps.toml` (delete `zed` lines; `ethereal` has no `apps.toml` — nothing to do there)
- Test: `test/test_theme_content.zsh` (add a no-`zed`-keys guard)

**Interfaces:**
- Consumes: nothing new. Produces: no `zed = …` line in any bundled `apps.toml`.

- [ ] **Step 1: Add the failing guard assertion**

Append to `test/test_theme_content.zsh`, immediately before its final `finish` line:

```zsh
# apps.toml must not carry dead `zed` keys (Zed theming is out of scope).
zedhits=0
for af in "$ROOT"/themes/*/apps.toml(N); do
  grep -Eq '^[[:space:]]*zed[[:space:]]*=' "$af" && (( zedhits++ ))
done
check "no apps.toml has a zed key" "0" "$zedhits"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zsh test/test_theme_content.zsh`
Expected: FAIL — `no apps.toml has a zed key` reports a nonzero count (the ported files still contain `zed = "…"`).

- [ ] **Step 3: Strip the `zed` lines**

Run (deletes any line whose first key is `zed`, in place, across all bundled themes):

```bash
for f in themes/*/apps.toml; do
  sed -i '' -E '/^[[:space:]]*zed[[:space:]]*=/d' "$f"
done
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `zsh test/test_theme_content.zsh`
Expected: PASS — `no apps.toml has a zed key` is `0`; every other assertion still passes.

- [ ] **Step 5: Commit**

```bash
git add themes/*/apps.toml test/test_theme_content.zsh
git commit -m "chore(theme): drop dead zed keys from apps.toml (Zed out of scope)"
```

---

### Task 4: SketchyBar battery plugin

Add a battery indicator (percentage + charge state) to the topbar. Colors come from the `colors.sh` seam so `theme` still owns them. `omac::wm::deploy_sketchybar` already deploys and `chmod +x`es every file under `plugins/`, so no engine change is needed — only the new plugin file and its `sketchybarrc` registration.

**Files:**
- Create: `wm/sketchybar/plugins/battery.sh`
- Modify: `wm/sketchybar/sketchybarrc` (register the `battery` item)
- Test: `test/test_wm_battery.zsh` (new)

**Interfaces:**
- Consumes: `$NAME` (set by SketchyBar), `LABEL_COLOR` (from `colors.sh`), `pmset -g batt`, `sketchybar --set`.
- Produces: `plugins/battery.sh` sets the `$NAME` item's `label` to `<pct>%` and an icon reflecting AC vs. battery. `sketchybarrc` adds a right-aligned `battery` item on a refresh timer.

- [ ] **Step 1: Write the failing test**

Create `test/test_wm_battery.zsh`:

```zsh
#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

# Structure: the real plugin exists, is executable, and is registered.
check "battery.sh exists"     "yes" "$([[ -f "$ROOT/wm/sketchybar/plugins/battery.sh" ]] && print yes || print no)"
check "battery.sh executable" "yes" "$([[ -x "$ROOT/wm/sketchybar/plugins/battery.sh" ]] && print yes || print no)"
check "sketchybarrc registers battery" "yes" "$(grep -q 'item battery' "$ROOT/wm/sketchybar/sketchybarrc" && print yes || print no)"

# Logic: stub pmset + sketchybar, provide a colors.sh, run the plugin.
stub="$(mktemp -d)"
export SKETCHYBAR_LOG="$(mktemp)"
cat > "$stub/pmset" <<'SH'
#!/usr/bin/env bash
printf "%s\n" "Now drawing from 'Battery Power'"
printf " -InternalBattery-0 (id=1)\t83%%; discharging; 4:32 remaining present: true\n"
SH
cat > "$stub/sketchybar" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$SKETCHYBAR_LOG"
SH
chmod +x "$stub/pmset" "$stub/sketchybar"

export HOME="$(mktemp -d)"
mkdir -p "$HOME/.config/sketchybar"
print -r -- 'export LABEL_COLOR=0xffcdd6f4' > "$HOME/.config/sketchybar/colors.sh"

PATH="$stub:$PATH" NAME=battery bash "$ROOT/wm/sketchybar/plugins/battery.sh"
contains "battery label shows percent" "label=83%" "$(<"$SKETCHYBAR_LOG")"
finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zsh test/test_wm_battery.zsh`
Expected: FAIL — `battery.sh exists` is `no` and `sketchybarrc registers battery` is `no`.

- [ ] **Step 3: Create the plugin**

Create `wm/sketchybar/plugins/battery.sh`:

```bash
#!/usr/bin/env bash
# Battery: percentage + charge state. Colors from the theme seam (colors.sh).
source "$HOME/.config/sketchybar/colors.sh"

batt="$(pmset -g batt)"
pct="$(printf '%s\n' "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
[ -z "$pct" ] && pct=0

# "Now drawing from 'AC Power'" when plugged in; anything else is on-battery.
if printf '%s\n' "$batt" | grep -q "'AC Power'"; then
  icon=""   # nf-md-power_plug — charging
else
  icon=""   # nf-md-battery — on battery
fi

sketchybar --set "$NAME" icon="$icon" label="${pct}%" label.color="$LABEL_COLOR"
```

Then make it executable:

```bash
chmod +x wm/sketchybar/plugins/battery.sh
```

- [ ] **Step 4: Register the item in `sketchybarrc`**

In `wm/sketchybar/sketchybarrc`, insert a battery item just before the `# Clock on the right.` block (before line 23). Add:

```bash
# Battery on the right (percentage + charge state).
sketchybar --add item battery right \
           --set battery update_freq=120 script="$HOME/.config/sketchybar/plugins/battery.sh" \
           --subscribe battery power_source_change system_woke
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `zsh test/test_wm_battery.zsh`
Expected: PASS — all five assertions succeed, ending `--- 5 passed, 0 failed ---`.

- [ ] **Step 6: Commit**

```bash
git add wm/sketchybar/plugins/battery.sh wm/sketchybar/sketchybarrc test/test_wm_battery.zsh
git commit -m "feat(wm): add SketchyBar battery plugin"
```

---

### Task 5: Full-suite verification

**Files:** none (verification only).

- [ ] **Step 1: Run the entire test suite**

Run: `zsh test/run.zsh`
Expected: every `test_*.zsh` reports `0 failed` and the runner exits 0. If any test fails, fix it in the owning task before proceeding — do not edit tests to pass.

- [ ] **Step 2: Confirm no stray Zed/`~/.config`-VSCode references remain**

Run:

```bash
grep -rniE '\bzed\b' lib/ cmd/ themes/*/apps.toml
grep -n 'config_dir).*Code/User' lib/theme.zsh
```

Expected: no matches in `lib/`/`cmd/`/`apps.toml` for a `zed` key or applier, and no VS Code write still going through `config_dir`. (Doc/spec mentions of the Zed-dropped decision are fine.)

- [ ] **Step 3: Commit any final cleanup (only if Step 2 surfaced something)**

```bash
git add -A
git commit -m "chore(theme): remove residual zed references"
```

## Self-Review

**Spec coverage (theme spec):** VS Code/Cursor macOS path → Task 1; bat applier → Task 2; git-delta applier reusing the bat name → Task 2; Zed removed from `apps.toml` → Task 3; `git`/`bat` stubs in `theme_stubs.zsh` → Task 2 Step 1; best-effort skip-when-unnamed → Task 2 Steps 2/4. **Spec coverage (wm spec):** battery plugin (percentage + charge state, colors from the seam, timer-refreshed, registered) → Task 4. Tweak-reversal deferral is a spec/plan doc change only (no code) — no task needed.

**Placeholder scan:** every code step contains complete code; no TBD/TODO; the battery-icon nerd-font glyphs are illustrative and not asserted (percentage label is), so tests are glyph-independent.

**Type/name consistency:** `appsupport_dir`, `apply_bat`, `apply_delta` are defined in Task 1/2 and called by `apply_vscode`/`set` in the same tasks; `BAT_LOG`/`GIT_LOG` are exported in Task 2 Step 1 and read in Task 2 Step 2; `apply_bat`/`apply_delta` both read the `bat` key via the existing `toml_get`, matching the spec's "delta reuses the bat name."
