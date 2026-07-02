# Contributing

## Repository layout

```
bin/omac         # dispatcher entrypoint
boot.sh          # curl … | zsh bootstrap installer
cmd/             # one file per command; cmd/<x>/<sub>.zsh for nested subcommands
lib/             # namespaced engines (theme, wm, software, migrate, …)
software/        # Brewfile groups + runtimes.manifest
wm/              # aerospace.toml, sketchybar config + plugins, macOS tweaks
themes/          # bundled themes (per-app files + colors.toml)
templates/       # palette-rendered templates for macOS-only targets
migrations/      # ordered migration scripts
test/            # zsh test suite
docs/            # this documentation site
```

## Running the tests

omac has a zsh test suite. Run the whole thing:

```bash
test/run.zsh
```

## Working on the docs site

The site is Material for MkDocs. Preview locally with live reload:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r docs-requirements.txt
mkdocs serve            # http://127.0.0.1:8000
mkdocs build --strict   # what CI runs; fails on broken links
```

Pushing to `main` rebuilds and publishes to GitHub Pages automatically.

## Recording the demo

The home-page demo is an [asciinema](https://asciinema.org) cast. The committed
`docs/assets/omac-theme.cast` is a placeholder; record the real one on a machine with omac
installed:

```bash
asciinema rec docs/assets/omac-theme.cast \
  --title "omac theme set" --cols 80 --rows 12 --overwrite
# in the recording: run `omac theme set kanagawa`, then `omac theme set tokyo-night`,
# so the desktop visibly recolors. Press Ctrl-D to stop.
```

Commit the new `.cast` — the player picks it up with no other changes.

## Adding a theme

Add a `themes/<name>/` directory with the per-app files and a `colors.toml` palette, then
`omac theme list` and `omac theme set <name>` to verify. Add the name to the table in
[Themes](../themes/index.md).

## Adding a command

Add `cmd/<name>.zsh` with a `# help:` header and a usage block, plus a matching test under
`test/`. Nested subcommands go in `cmd/<name>/<sub>.zsh`. Document it under
[Commands](../commands/index.md).
