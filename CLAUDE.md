# CLAUDE.md

Guidance for working in **omac** — an Omarchy-style, keyboard-driven, fully-themed desktop *layer*
for macOS (Apple Silicon, macOS 14+). omac is not a distro; it composes mature macOS tools and adds
the one piece the Mac lacks: a theme-orchestration layer.

**Lineage** (mind the philosophy, not just the code):
- **[Omarchy](https://github.com/basecamp/omarchy)** — the north star. Its themes, keyboard-driven
  desktop, and XDG layout are what omac ports to macOS. When in doubt about *what* a feature should
  do, ask "what does Omarchy do?"
- **[Omakos](https://github.com/yatish27/omakos)** — the model for idempotent, re-runnable,
  declarative Homebrew provisioning. When in doubt about *how* to install/deploy safely, follow
  omakos' non-destructive patterns.

## Architecture

Single entrypoint `bin/omac` resolves `omac <cmd> [<sub>]` to a script:
- `cmd/<cmd>.zsh` (flat) or `cmd/<cmd>/<sub>.zsh` (nested) — resolved by `omac::resolve`.
- Each `cmd/` script carries a `# help: …` header that `omac help` reads.
- **`cmd/` scripts stay thin** (usage + dispatch). All real logic lives in namespaced engines under
  `lib/`, one per module, functions named `omac::<module>::…`.

Five modules, built in order, each an independent sub-project:
`bootstrap` → `software` → `wm` → `launcher` → `theme`. See `docs/architecture/index.md`.

The **theme seam** is hybrid: file-per-app configs dropped in almost unchanged where Omarchy already
had them, and palette-derived rendering (from a small `colors.toml`) for macOS-only targets
(appearance, JankyBorders, Raycast, AeroSpace). `omac theme set` repoints the `~/.config/omac/current`
symlink, re-renders derived targets, and reloads each app.

## Conventions

- **zsh, not bash** for all `bin/`, `cmd/`, `lib/`, `test/` code (`shell/omac.bash` is the exception:
  user-facing shell wiring). Every script opens with `emulate -L zsh`; `bin/omac` sets
  `setopt no_unset pipe_fail`.
- **Reuse `lib/common.zsh` helpers** — don't reinvent them:
  - `omac::info/ok/log/warn/error` — the only output style (`→ ✓ ! ✗`). No raw `echo`.
  - `omac::install_file <src> <dest>` — idempotent, non-destructive deploy (skip if identical, back
    up + prompt if differing). Declining the prompt returns non-zero — callers must stop, not skip.
  - `omac::backup_path`, `omac::ensure_block`/`omac::remove_block` (marker-delimited managed blocks),
    `omac::confirm`, `omac::require_cmd`.
- **Idempotent & re-entrant always** — every command must be safe to re-run. Never overwrite a user
  file without `omac::install_file`/`omac::backup_path`.
- **Paths come from `lib/paths.zsh`** — XDG-on-macOS (`~/.local/share/omac` = read-only repo,
  `~/.config/omac` = user state). Every path is a `: ${VAR:=default}` override so tests can redirect
  them. Never hardcode a path a test can't stub.

### zsh gotchas (already bit us — see comments in `lib/common.zsh`)
- `$path` is tied to `$PATH` in zsh — never `local path=…`; it clobbers PATH for the scope.
- Prompts read from `/dev/tty`, not stdin: under `curl … | zsh` stdin is the script itself. No tty
  (CI) → fail safe to "no".
- Use the `zsh/datetime` `strftime` builtin over a `date` subprocess.

## Testing

The suite is **offline and hermetic** — `brew`/`mise` are stubbed, no network, runs on any platform
(CI uses `macos-latest` for parity). Run it before every change:

```bash
zsh test/run.zsh                 # full offline unit suite
zsh test/validate_manifests.zsh  # resolve every brew/cask token vs real Homebrew (needs brew)
```

- Assertions live in `test/helper.zsh`: `check <desc> <expected> <actual>`, `contains`, `finish`.
- Tests set `OMAC_HOME`, and point `OMAC_CONFIG`/XDG dirs at `mktemp -d`. Stub external tools via the
  `*_stubs.zsh` files. New behavior needs a `test/test_*.zsh` file (auto-discovered by `run.zsh`).
- CI (`.github/workflows/ci.yml`) runs both the suite and manifest validation on every push/PR.

## Adding a command

1. Create `cmd/<name>.zsh` (or `cmd/<name>/<sub>.zsh`) with a `# help:` header; keep it thin.
2. Put logic in `lib/<name>.zsh` as `omac::<name>::…` functions; `source` the lib from the cmd.
3. Add any new path as an overridable `: ${OMAC_…:=…}` in `lib/paths.zsh`.
4. Add a `test/test_<name>_*.zsh` covering it. Run `zsh test/run.zsh`.
