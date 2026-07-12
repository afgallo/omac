# Services

macOS lacks a system package manager for background data services, so omac ships
a **default dev stack** — Postgres + Redis — running as containers on a
lightweight Docker daemon. No Docker Desktop, no GUI, no license: just
[Colima](https://github.com/abiosoft/colima) (a Lima VM providing the Docker
daemon) plus the `docker` CLI and `docker compose`.

```bash
omac software install containers   # colima + docker + docker-compose
omac services up                   # deploy, start, and enable at login
```

## What you get

| Service | Image | Port | Persistence |
|---|---|---|---|
| Postgres | `postgres:17-alpine` | `5432` | named volume `pgdata` |
| Redis | `redis:7-alpine` | `6379` | named volume `redisdata` (AOF + snapshots) |

Both declare `restart: unless-stopped` and healthchecks, so they come back with
the daemon and report readiness.

Default Postgres credentials (local-dev only — **not secrets**):

```
user: omac   password: omac   database: omac
```

Connect with the `pgcli` from the [`tuis` group](../software/index.md):

```bash
pgcli postgresql://omac:omac@localhost:5432/omac
redis-cli -p 6379 ping
```

## Configuration

`omac services up` deploys two files to `~/.config/omac/services/`, then never
clobbers them:

- `docker-compose.yml` — the stack definition.
- `.env` — credentials and host ports (`POSTGRES_*`, `REDIS_PORT`).

Edit either and re-run `omac services up` to apply. The Colima VM defaults to
2 CPU / 4 GB RAM / 20 GB disk (override with `OMAC_COLIMA_CPU`,
`OMAC_COLIMA_MEMORY`, `OMAC_COLIMA_DISK`).

## Out of the box

The first `omac services up` installs a login LaunchAgent
(`~/Library/LaunchAgents/com.omac.services.plist`) that runs `omac services boot`
— starting Colima and the stack — at every login, so the databases are up
without you thinking about it. `omac doctor` reports whether the tooling is
installed and the daemon is running.

Manage the stack with the [`omac services`](../commands/services.md) command.
