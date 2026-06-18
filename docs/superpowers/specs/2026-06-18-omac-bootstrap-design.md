# omac · sub-project 1: `bootstrap` — Design

**Status:** Approved design · **Date:** 2026-06-18 · **Parent:** [omac master design](2026-06-18-omac-design.md)

## Purpose

The foundation every other module installs through: the `omac` CLI command center, a curl-able
installer that provisions the base system, and the update + migration engine. Mirrors Omarchy's
`boot.sh` + `bin/` + `migrations/` model, adapted to macOS/Homebrew/zsh.

## Scope

**In:** install location convention, `boot.sh` entry point, Homebrew bootstrap, the `omac` zsh CLI
dispatcher framework, a small set of foundational commands (`help`, `version`, `update`, `doctor`,
`path`), the update flow, and the migration engine.

**Out (owned by later modules, only *registered* here):** `theme`, `install`/`software`, `wm`,
`launcher` subcommands. Bootstrap ships the dispatcher; modules drop their command scripts in.

## Install locations (mirrors Omarchy)

| Path | Role |
|---|---|
| `~/.local/share/omac` | System files — the cloned repo (scripts, defaults, migrations). |
| `~/.config/omac` | User config — overrides, selected theme, local state. |
| `~/.local/state/omac/migrations` | Applied-migration ledger (one marker per ran migration). |
| `/opt/homebrew/bin/omac` (symlink) | `omac` on PATH → `~/.local/share/omac/bin/omac`. |

Apple-silicon Homebrew prefix `/opt/homebrew` assumed; installer detects `$(brew --prefix)` rather
than hardcoding.

## Components

### 1. `boot.sh` — curl-able entry point
`curl -fsSL <url> | zsh`. Steps, each idempotent:
1. Verify macOS + arch; refuse unsupported.
2. Install Xcode Command Line Tools if absent.
3. Install Homebrew if absent; otherwise `brew update`.
4. Clone `omac` to `~/.local/share/omac` (or `git pull` if present).
5. Run `omac install` core steps (symlink CLI onto PATH, seed `~/.config/omac`).
6. Print next steps.

### 2. `bin/omac` — zsh dispatcher
- `omac <command> [args...]` resolves to `~/.local/share/omac/cmd/<command>.zsh` (nested commands
  → `cmd/<command>/<subcommand>.zsh`).
- Sources a shared `lib/` (logging, `confirm`, `require_cmd`, color helpers).
- `omac` with no args prints help; unknown command prints help + nonzero exit.
- Modules extend the CLI by adding files under `cmd/` — no dispatcher changes needed.

### 3. Foundational commands
- `omac help` — lists registered commands with one-line descriptions (parsed from a header comment).
- `omac version` — prints version from the repo's `version` file + short git SHA.
- `omac update` — `git pull` the repo → `brew bundle` (if a Brewfile exists) → run pending
  migrations → reload shell hint. Safe to re-run.
- `omac doctor` — sanity checks: brew present, paths exist, CLI symlink valid, zsh version, PATH
  contains brew prefix. Reports pass/warn/fail; nonzero exit on fail.
- `omac path` — prints the system + config dirs (used by other scripts/tests).

### 4. Migration engine
- Migrations are timestamped zsh files in `migrations/` (e.g. `20260618120000-example.zsh`).
- `omac update` runs any whose marker is absent from `~/.local/state/omac/migrations`, in order,
  then writes the marker. Each migration is idempotent and single-purpose.
- Mirrors Omarchy's migration model so config changes ship safely to an existing install.

## Idempotency & safety

- Every install/boot step checks-then-acts; re-running is a no-op when already satisfied.
- No hardcoded usernames/paths; derive `$HOME`, `$(brew --prefix)`, repo dir at runtime.
- Destructive actions (overwriting an existing non-omac config) prompt via `confirm` unless
  `OMAC_YES=1`.

## Testing

- `omac doctor` is the runtime smoke test.
- Shell-level tests (bats or simple zsh assertions) for: dispatcher resolution, help parsing,
  migration ledger (runs once, skips on second pass), idempotent install on a clean vs seeded HOME.
- CI-friendly: installer honors `OMAC_HOME`/`OMAC_PREFIX` overrides so tests run in a temp dir.

## Deliverables

`boot.sh`, `bin/omac`, `lib/` helpers, `cmd/` (help, version, update, doctor, path), `migrations/`
scaffold + one example migration, `version` file, and the install-location bootstrap. Other modules
build on this in their own sub-project cycles.

## Open questions (resolved here)

- **CLI language:** zsh (decided).
- **Repo vs config split:** system in `~/.local/share/omac`, user state in `~/.config/omac` (decided).
- **Test framework:** start with plain zsh assertion scripts; adopt `bats` only if they get unwieldy.
