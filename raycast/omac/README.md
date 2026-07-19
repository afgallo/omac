# omac — Raycast command palette

One Raycast command, **omac**, that lists every omac command and runs it — the
same actions as the CLI, one keystroke from anywhere.

The palette is driven entirely by `omac commands --json` (the command registry in
`lib/registry.zsh`), so it never drifts from the CLI: add a command to omac and it
shows up here automatically, grouped and labeled the same way.

## What each command does

Every command carries a `kind` that decides how the palette runs it:

| kind | in the palette |
|---|---|
| `read` | runs inline, shows the output in a Detail pane |
| `apply` | runs inline (a quick, non-interactive change), shows output + a toast |
| `pick` | pick a value (theme, font, group) from a dropdown, then runs it |
| `mutate` | hands off to **Ghostty** — a real terminal — for interactive/privileged work |

## Install it locally (development mode)

This extension is distributed with omac, not the Raycast Store. To use it:

```bash
cd raycast/omac
npm install
npm run dev      # builds + adds "omac" to your local Raycast, then watches
```

Leave `npm run dev` running the first time so Raycast imports it; after that the
command **omac** is available in Raycast permanently. Press ⌃C when you're done —
the imported command stays. Trigger it by typing `omac` in Raycast.

To rebuild without the watcher:

```bash
npm run build
```

## Finding the omac binary

The extension locates `omac` by checking, in order: the **omac binary** path in
its preferences (⌘, in Raycast), then the usual install locations
(`~/.local/bin`, Homebrew), then `command -v omac` in a login shell. If your omac
lives somewhere unusual, set the preference.

## Theming

The palette follows your omac theme: `omac theme set <name>` also pushes a matching
palette to Raycast (named **omac**) via Raycast's theme deeplink. Applying a custom
theme requires Raycast Pro.
