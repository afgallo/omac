# omac · sub-project 1: `bootstrap` — Design

**Status:** Approved design (revised after adversarial review) · **Date:** 2026-06-18 · **Parent:** [omac master design](2026-06-18-omac-design.md)

## Purpose

The foundation every other module installs through: the `omac` CLI command center, a curl-able
installer that provisions the base system, and the update + migration engine. Mirrors Omarchy's
`boot.sh` + `bin/` + `migrations/` model, adapted to macOS/Homebrew/zsh.

**The one promise this module must keep:** after `boot.sh`, `omac` is runnable in a *fresh* shell
and user config is actually loaded. Tests must exercise that, not just file creation.

## Scope

**In:** preflight/prerequisite checks, install location convention, `boot.sh` entry point, Homebrew
bootstrap, shell integration (PATH + config sourcing), the `omac` zsh CLI dispatcher (flat **and**
two-level nested commands), foundational commands (`help`, `version`, `update`, `doctor`, `path`,
`install`, `uninstall`), the update flow, and the migration engine.

**Out (owned by later modules, only *registered/reserved* here):** `theme`, `software`, `wm`,
`launcher` subcommands and their config rendering. Bootstrap ships the dispatcher + reserves the
`themes/`/`templates/`/`current` layout; modules drop their command scripts and content in.

## Prerequisites & preflight (enforced by `boot.sh`)

| Check | Rule | On failure |
|---|---|---|
| OS | `uname -s` == Darwin | abort |
| Architecture | `uname -m` == arm64 (Apple Silicon only) | abort |
| macOS version | major ≥ 14 (Sonoma; supports 14 + 15) | abort with version message |
| Network | can reach github.com | abort |
| Admin rights | implied (Homebrew/CLT need sudo) | surfaced by the failing step |
| Xcode CLT | auto-installed if absent | abort + "rerun after CLT finishes" |
| Homebrew | auto-installed if absent | abort if install fails |

A clean macOS install is recommended but **not required**; every step is idempotent and
re-runnable (see below).

## Install locations (mirrors Omarchy; see master spec → Canonical paths)

| Path | Role | Override (tests) |
|---|---|---|
| `~/.local/share/omac` | System files — the cloned repo. | `OMAC_HOME` |
| `~/.local/share/omac/themes` · `…/templates` | Reserved for the `theme` module. | — |
| `~/.config/omac` | User config — `config.zsh`, overrides, state. | `OMAC_CONFIG` |
| `~/.config/omac/current` | Symlink → active theme dir (reserved). | `OMAC_CURRENT` |
| `~/.local/state/omac/migrations` | Applied-migration ledger. | `OMAC_STATE` |
| `~/.zprofile` | Managed block for shell integration. | `OMAC_PROFILE` |
| `/opt/homebrew/bin/omac` (symlink) | `omac` on PATH. | `OMAC_PREFIX` |

Apple-silicon Homebrew prefix `/opt/homebrew` is fixed; `omac::prefix` still reads `$(brew --prefix)`
(honoring `OMAC_PREFIX` for tests) rather than hardcoding.

## Components

### 1. `boot.sh` — curl-able entry point
`curl -fsSL <url> | zsh`. Steps, each idempotent and re-entrant:
1. Run all preflight checks (table above); abort early on any failure.
2. Install Xcode Command Line Tools if absent.
3. Install Homebrew if absent; then `eval "$(/opt/homebrew/bin/brew shellenv)"` for this process.
4. Clone `omac` to `~/.local/share/omac`. **Re-entrant:** if the path is a valid git repo →
   `git pull --ff-only`; if it exists but is *not* a valid repo (interrupted clone) → remove and
   re-clone (prompt when interactive); else fresh clone. Abort on clone/pull failure.
5. Run `omac install`.
6. Print next steps.

### 2. `bin/omac` — zsh dispatcher
- Sources `lib/paths.zsh` + `lib/common.zsh`, then **sources `~/.config/omac/config.zsh` if present**
  (this is how user overrides like `OMAC_DEFAULT_THEME` take effect).
- Resolves commands with **two-level nesting**: `omac theme set` → `cmd/theme/set.zsh`, falling back
  to `cmd/theme.zsh`, falling back to flat `cmd/<command>.zsh`. This is built now because the very
  next module (`software`/`theme`) uses nested grammar — deferring it would force module 2 to edit
  the dispatcher.
- Command scripts run inside an `omac::run` function so `local`/`typeset` and `return N` behave and
  exit status propagates. Modules extend the CLI purely by adding files under `cmd/`.
- No args → help; unknown command → help + nonzero exit.

### 3. Foundational commands
- `omac help` — lists registered commands with one-line descriptions (from a `# help:` header).
- `omac version` — version file + short git SHA.
- `omac path` — prints all resolved dirs (incl. reserved `themes`/`templates`/`current`), the
  machine-readable seam other modules/Raycast/SketchyBar use to locate omac.
- `omac doctor` — health checks: brew present, **brew prefix on `$PATH`**, paths exist, CLI symlink
  valid, config sourced, zsh ≥ 5. Reports pass/warn/fail; **nonzero exit on any fail** (tested).
- `omac update` — `git pull --ff-only` → `brew bundle` (if a Brewfile exists) → run pending
  migrations → done. Guarded steps skip cleanly when not applicable. Safe to re-run.
- `omac install` — idempotent: create dirs, symlink CLI onto PATH, **write the `~/.zprofile`
  managed block** (`eval "$(/opt/homebrew/bin/brew shellenv)"`), seed `~/.config/omac/config.zsh`.
- `omac uninstall` — reverse of install: remove CLI symlink, remove the managed `~/.zprofile` block
  by markers, and (behind `confirm`) delete config + state. Makes clean re-test possible.

### 4. Shell integration (the BLOCKER the review caught)
On Apple Silicon `/opt/homebrew/bin` is **not** on PATH by default. `omac install` writes a
marker-delimited managed block to `~/.zprofile`:
```
# >>> omac >>>
eval "$(/opt/homebrew/bin/brew shellenv)"
# <<< omac <<<
```
This puts both `brew` and the `omac` symlink on PATH in every new login shell. The block is
idempotent (skipped if its begin-marker is already present) and removable by marker (uninstall).

### 5. Migration engine
- Migrations are timestamped zsh files in `migrations/` (e.g. `20260618120000-example.zsh`).
- `omac update` runs any whose marker is absent from `~/.local/state/omac/migrations`, in order,
  writing the marker **only after** a migration exits 0. A failed migration is *not* marked, so it
  reruns next time.
- **Hard rule (not just convention):** every migration MUST be internally idempotent — it may run
  partially then fail and be rerun from the top. Use check-then-act, never blind mutation.
  Anti-pattern: `echo X >> file` (doubles on rerun). Correct: `grep -q X file || echo X >> file`.
  Destructive migrations back up before mutating.

## Idempotency & safety

- Every install/boot step checks-then-acts; re-running is a no-op when already satisfied.
- No hardcoded usernames/paths; derive `$HOME`, `$(brew --prefix)`, repo dir at runtime.
- Destructive actions (overwriting non-omac config, deleting dirs) prompt via `confirm` unless
  `OMAC_YES=1`.
- Clone step is re-entrant against an interrupted prior run (see boot.sh step 4).

## Testing

- `omac doctor` is the runtime smoke test; its **nonzero-exit-on-failure path is explicitly tested**.
- Shell-level tests (plain zsh assertions) cover: flat + nested dispatcher resolution, config
  sourcing (an override in `config.zsh` is visible to a command), help parsing, migration ledger
  (runs once, skips second), idempotent install incl. the `.zprofile` managed block, and uninstall
  removing symlink + block.
- Tests invoke the CLI as `zsh bin/omac …` (no dependency on the executable bit) and route every
  real location through an override (`OMAC_HOME/CONFIG/STATE/PREFIX/PROFILE`) into temp dirs — no
  test touches the real `~/.zprofile`, PATH, or git remote.

## Deliverables

`boot.sh`, `bin/omac`, `lib/` (`paths`, `common`, `migrate`), `cmd/` (help, version, path, doctor,
update, install, uninstall), reserved `themes/` + `templates/` dirs, `migrations/` scaffold + one
example migration, `default/config.zsh`, `version`, and the install/shell-integration bootstrap.

## Resolved decisions

- **CLI language:** zsh.
- **Repo vs config split:** system in `~/.local/share/omac`, user state in `~/.config/omac`; XDG
  fallbacks explicit (macOS sets no `$XDG_*`).
- **Nested command resolution:** built now (next module needs it).
- **Shell integration:** managed `~/.zprofile` block via `brew shellenv` (Apple Silicon → `/opt/homebrew`).
- **Uninstall:** included in this module (pairs with the managed-block markers).
- **Test framework:** plain zsh assertions; adopt `bats` only if they get unwieldy.

## Deferred (noted, not built here)

- `omac env`/`--json` machine-readable output for downstream scripts (launcher module).
- Actual theme rendering, templates content, and `current` symlink *management* (theme module) —
  bootstrap only reserves the paths.
- `update` aborting vs warning on a failed non-ff pull: warns and continues for now (migrations from
  the old tree are already marked; new ones simply don't arrive until git state is resolved).
