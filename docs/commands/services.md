# omac services

Run the default local dev stack — **Postgres + Redis** — on a lightweight
[Colima](https://github.com/abiosoft/colima) Docker daemon.

```
omac services up       deploy + start the stack; enable it at login
omac services down     stop the stack (data volumes are kept)
omac services status   show daemon + container status
omac services logs     tail container logs
```

`omac services up` deploys `docker-compose.yml` and `.env` to
`~/.config/omac/services/` (non-destructively — your edits survive), starts the
Colima daemon, brings the containers up, and installs a login LaunchAgent so the
stack is running out of the box after every reboot.

The tooling (`colima`, `docker`, `docker-compose`) installs with the
[`containers` software group](../services/index.md):

```bash
omac software install containers
```

See [Services](../services/index.md) for defaults, credentials, and ports.
