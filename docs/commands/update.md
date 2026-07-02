# omac update

Update omac: `git pull`, `brew bundle`, and run any pending migrations.

```bash
omac update
```

Migrations are tracked in a ledger under `~/.local/state/omac/migrations`; a failed migration is
skipped into a separate ledger instead of blocking later ones. On a fresh install, existing
migrations are baselined as applied so a new machine never replays history.
