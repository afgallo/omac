# Install

Run the bootstrap. It is safe to re-run — the same command installs or updates.

```bash
curl -fsSL https://raw.githubusercontent.com/afgallo/omac/main/boot.sh | zsh
```

## What the bootstrap does

1. **Preflight** — verifies macOS (Darwin), Apple Silicon, macOS 14+, and HTTPS reachability to
   github.com.
2. **Xcode Command Line Tools** — installs them if missing (rerun the bootstrap once they finish).
3. **Homebrew** — installs it if missing, then loads its shell environment.
4. **Clone or update** — clones the repo to `~/.local/share/omac`, or `git pull --ff-only`s an
   existing checkout (re-entrant; a half-finished clone is detected and offered a re-clone).
5. **Core install** — runs `omac install` to wire the CLI, shell integration, and base config.

When it finishes:

```
✓ omac installed. Open a new terminal, then run: omac doctor
```

!!! tip "Open a new terminal"
    Shell integration is picked up by new shells. Open a fresh terminal window before running
    `omac` commands.
