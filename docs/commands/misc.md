# omac version & path

## version

Print the omac version.

```bash
omac version
```

## path

Print the resolved omac directories — useful when debugging where omac reads and writes.

```bash
omac path
```

Prints `OMAC_HOME`, `OMAC_CONFIG`, `OMAC_STATE`, `themes`, `templates`, `current`, `profile`, and
the Homebrew `prefix`. These follow an XDG-on-macOS layout: repo at `~/.local/share/omac`, user
state at `~/.config/omac`, and the migration ledger at `~/.local/state/omac`.
