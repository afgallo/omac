# omac install

Install or repair the omac CLI, shell integration, and base config.

```bash
omac install
```

Idempotent: it wires the `omac` command onto your `PATH`, adds shell integration, and lays down
base config without clobbering existing files (managed blocks, confirm-before-overwrite). Run it
again any time to repair a broken install. This is the step the bootstrap runs for you at the end
of a fresh install.
