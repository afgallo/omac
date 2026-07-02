# omac `launcher` module — design

**Status:** Approved design · **Date:** 2026-07-02 · **Parent:** `2026-06-18-omac-design.md` (module 4 of 5)

## What this is

The `launcher` module is the **guided first-run activation layer for Raycast** — the direct
counterpart to what `wm` does for AeroSpace + SketchyBar. Its single responsibility is to take an
installed-but-unconfigured Raycast and hand-hold it into being the user's keyboard launcher: free up
the ⌘Space hotkey, open Raycast and the relevant settings panes, and print the short checklist of
GUI-only steps macOS and Raycast forbid scripting.

It **installs nothing** (that is `software`, which ships the `raycast` cask in `guis.Brewfile`) and
**styles nothing** (that stays `theme`). It is a pure activation layer, deliberately thin.

### Scope change from the pre-spec decisions doc

`2026-07-02-omac-launcher-decisions.md` proposed two v1 pillars: (1) **omac CLI Script Commands + an
"Omarchy Menu"** surface, and (2) guided Raycast activation. This spec **supersedes that doc** and
**defers pillar 1 to v1.1/v2**. Reasons: the Script Commands carry real runtime hazards under
Raycast's non-interactive shell (no TTY, minimal PATH — see that doc's "Runtime gotchas"), and the
guided-activation pillar delivers the day-one value on its own. What remains in v1 is pillar 2 only.

## Goals

- `omac launcher install` takes an installed Raycast to "it is my launcher on ⌘Space" in one command,
  automating the one scriptable step and hand-holding the manual ones — mirroring `wm`'s guided
  first-run.
- The one genuinely scriptable step — freeing ⌘Space from Spotlight — is idempotent and reversible.
- One engine (`lib/launcher.zsh`) is the single source of truth; `cmd/launcher/*` scripts are thin.
- Honest about its own limits: the GUI-only Raycast settings are surfaced as a guided checklist, not
  pretended to be automated.

## Non-goals (v1 — deferred to v1.1/v2)

- **No omac Script Commands / "Omarchy Menu."** The Raycast-Script-Command surface that calls the
  `omac` CLI is deferred. Its no-TTY / PATH-resolution hazards are unresolved and out of v1 scope.
- **No Raycast color theming.** Recoloring the Raycast window from the active palette stays a
  `theme`-module concern (currently unbuilt). Launcher owns activation, not colors.
- **No clipboard-history / snippets seeding.** Enabling Clipboard History is a guided manual step,
  not a scripted one; snippets seeding is deferred (lowest-value / most personal).
- **No web-app quicklinks.** The ChatGPT/Claude/Email/YouTube/X launches remain AeroSpace `open <url>`
  bindings in `wm` for now; not relocated into Raycast.
- **No package installation.** The `raycast` cask comes from `software`.

## Why the module is thinner than `wm`

`wm` deploys config files (`aerospace.toml`, the SketchyBar tree) and therefore needs a source tree
(`wm/`) and an `OMAC_WM` override so tests can point at a fixture dir. **`launcher` deploys zero
config files** — Raycast's settings are not file-based configuration omac can write. So this module
has **no `launcher/` asset directory and no `OMAC_LAUNCHER` env override**; adding either would be
dead weight. The module is code (`lib/` + `cmd/`) plus guidance only. This is a deliberate,
justified deviation from the `wm`/`software` shape, not an oversight.

## What is scriptable vs. guided

This split is the honest core of the module.

**Scriptable (exactly one meaningful step):**

- **Free up ⌘Space.** macOS Spotlight owns ⌘Space via **symbolic hotkey `64`** (the "Show Spotlight
  search" shortcut) in the `com.apple.symbolichotkeys` domain. Disabling it lets Raycast claim
  ⌘Space. Done with `defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 …`
  followed by the `activateSettings -u` trick (see below) so the change applies live without a
  re-login. Idempotent and reversible.

**Guided (GUI-only — cannot be scripted):**

- Setting Raycast's launcher hotkey to ⌘Space (Raycast prompts for this on first launch; it lives in
  Raycast's own prefs, not a writable file).
- Enabling Clipboard History (a Raycast extension + its own hotkey).
- Granting Accessibility (window-management permission) to Raycast.

`omac launcher install` automates the first and, for the rest, opens Raycast and the relevant panes
and prints a short numbered checklist.

### The `activateSettings -u` trick

Changes to `com.apple.symbolichotkeys` are read by the WindowServer/loginwindow and normally only
take effect on next login. Running
`/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u`
after the `defaults write` reloads the keyboard-shortcut settings live. If that binary is absent (OS
version differences), the module falls back to printing "log out and back in for ⌘Space to take
effect" rather than failing.

## Layout

```
lib/launcher.zsh              # the engine — all logic lives here; namespaced omac::launcher::*
cmd/launcher.zsh              # bare `omac launcher` → usage + note unknown subcommand
cmd/launcher/install.zsh      # omac launcher install → free ⌘Space + guided activation
cmd/launcher/status.zsh       # omac launcher status  → non-mutating report
```

No `reload` subcommand — there is nothing to reload. This mirrors the `wm`/`software` "thin commands
over one namespaced engine" shape, minus the asset tree.

### Dispatcher fit (no changes to `bin/omac`)

The existing depth-2 resolver already supports this shape:

- `omac launcher install` → matches `cmd/launcher/install.zsh` (depth 2); the dispatcher consumes the
  `install` token.
- `omac launcher status` → `cmd/launcher/status.zsh`.
- `omac launcher` (bare) → depth-2 branch skipped, falls to `cmd/launcher.zsh` (depth 1) → usage.
- `omac launcher bogus` → no `cmd/launcher/bogus.zsh`, falls to `cmd/launcher.zsh` with `$1=bogus`;
  usage notes the unknown subcommand and returns non-zero (same convention as `cmd/wm.zsh`).

## The engine — `lib/launcher.zsh`

All logic lives here so `cmd/launcher/*` stay thin. Functions are namespaced `omac::launcher::<verb>`.

| Function | Behavior |
|---|---|
| `omac::launcher::raycast_present` | True iff `/Applications/Raycast.app` exists. Raycast ships **no** PATH binary, so detect the app bundle, not `command -v raycast`. |
| `omac::launcher::spotlight_hotkey_enabled` | Best-effort read of symbolic hotkey `64`'s `enabled` state (via `defaults read`), used by `status` and for idempotency. Absent/unreadable → treat as enabled. |
| `omac::launcher::free_spotlight_hotkey` | Disable Spotlight ⌘Space (symbolic hotkey `64`) via `defaults write … -dict-add`, then `activateSettings -u` to apply live (fallback message if that binary is missing). Idempotent — a no-op if already disabled. |
| `omac::launcher::activate` | `open -a Raycast`; open the Keyboard/Spotlight settings pane and the Accessibility pane; print the numbered manual checklist (set ⌘Space in Raycast, enable Clipboard History, grant Accessibility). |
| `omac::launcher::status` | Non-mutating: Raycast installed? running (`pgrep -x Raycast`)? Spotlight ⌘Space freed? Prints a small table. Performs no writes. |
| `omac::launcher::install` | Guard Raycast present (else hard error → `omac software install`) → `free_spotlight_hotkey` → `activate`. |
| `omac::launcher::restore_spotlight_hotkey` | Reversal: re-enable symbolic hotkey `64`, then `activateSettings -u`. Called by the uninstall path. |

Guards: a missing `/Applications/Raycast.app` is a hard error that points the user at
`omac software install` (which owns the cask); non-zero return. A missing `defaults` is a hard error
(it is part of macOS, so this only trips in a broken environment).

## First-run activation (guided auto-start)

`omac launcher install` runs the full guided flow, all steps idempotent/re-runnable:

1. Guard: Raycast app present (else error → `omac software install`).
2. `free_spotlight_hotkey`: disable Spotlight ⌘Space + `activateSettings -u`.
3. `activate`: `open -a Raycast`; `open "x-apple.systempreferences:…Keyboard"` and
   `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`; print the
   numbered checklist of the GUI-only steps.

## CLI surface

- `omac launcher` → usage + one-line intent; unknown subcommand token → warn + return 1.
- `omac launcher install` → the guided flow above.
- `omac launcher status` → Raycast installed / running / ⌘Space freed.

## Reversibility

Freeing ⌘Space has a clean inverse, so it is fully reversible — no one-way tweak here. The uninstall
path (via `omac uninstall` and/or a launcher reversal) calls `restore_spotlight_hotkey` to re-enable
Spotlight's ⌘Space and re-applies with `activateSettings -u`. Raycast's own GUI settings are the
user's to revert in-app (omac never wrote them).

## Error handling

| Situation | Behavior |
|---|---|
| `/Applications/Raycast.app` missing | Hard error pointing at `omac software install`; non-zero. |
| `activateSettings` binary absent | Warn and print "log out and back in for ⌘Space to take effect"; continue (non-fatal). |
| `defaults` missing | Hard error (broken macOS environment); non-zero. |
| ⌘Space already freed | `free_spotlight_hotkey` is a no-op; report "already done". |
| Unknown subcommand | Usage notes it; non-zero. |

## Testing

Follows the existing `test_*.zsh` pattern (`check`/`contains`/`finish`; fake system binaries on a
temp `PATH` that log their args, per `wm_stubs.zsh`/`software_stubs.zsh`). Real system state must
never be touched.

- **Stub `defaults`, `open`, `pgrep`, and `activateSettings`** on a temp dir prepended to `PATH`;
  each logs its arguments and exits 0. A `launcher_stubs.zsh` helper adds these (the `activateSettings`
  stub is placed under a temp dir and invoked by absolute path, or the engine resolves it via a
  `OMAC_ACTIVATE_SETTINGS`-style seam pointed at the stub — decided in the plan).
- **Redirect Raycast detection** so the app-present guard can be toggled without a real install
  (e.g. an `omac::launcher::raycast_present` that honors a test seam / temp app-dir).

Assertions:

- Guard: with Raycast absent, `omac launcher install` exits non-zero and hints `omac software install`.
- `install` calls `defaults write com.apple.symbolichotkeys` referencing hotkey `64` (assert on the
  `defaults` log) and opens Raycast + the settings panes (assert on the `open` log).
- `install` invokes `activateSettings -u` (assert on its log), and degrades gracefully when that stub
  is removed (prints the re-login hint, still exits 0).
- `status` performs no writes (empty `defaults`-write log) and reports the three facts.
- `restore_spotlight_hotkey` re-enables hotkey `64` (assert on the `defaults` log).
- `omac launcher` (bare) prints usage, exit 0; `omac launcher bogus` → non-zero.

## New env override

None user-facing. The module deploys no assets, so there is **no `OMAC_LAUNCHER`**. Any test seam
needed to stub `activateSettings` or Raycast detection is an internal detail settled in the plan, not
a documented user-facing knob.

## Open questions

None. The Script-Command "Omarchy Menu" is explicitly deferred to v1.1/v2 (with its no-TTY / PATH
hazards to resolve then); Raycast color theming remains a future `theme`-module concern.
