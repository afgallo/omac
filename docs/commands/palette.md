# omac command palette

Run every omac command from Raycast. Type `omac` in Raycast and the palette lists the same
commands as the CLI — grouped and labeled identically — one keystroke from anywhere.

The palette is a Raycast extension shipped in the repo (`raycast/omac/`), imported in
development mode rather than from the Raycast Store. `omac launcher install` builds it and
`omac launcher status` reports whether it is present and built.

## How it stays in sync

The palette is driven entirely by `omac commands --json` — the command registry in
`lib/registry.zsh`. It never hard-codes the command set, so it can't drift from the CLI: add a
command to omac and it appears in the palette automatically, in the same group with the same
title, description, and behavior.

## How each command runs

Every command carries a `kind` that decides how the palette runs it:

| kind | in the palette |
|---|---|
| `read` | runs inline, shows the output in a Detail pane |
| `apply` | runs inline (a quick, non-interactive change), shows output + a toast |
| `pick` | choose a value (theme, font, group) from a list, then runs it |
| `mutate` | hands off to **Ghostty** — a real terminal — for interactive or privileged work |

`read`/`apply` commands run through a login shell so brew- and mise-backed subcommands see the
same environment they would in a terminal. `mutate` commands (installs, updates, service
control) open in Ghostty so you can watch progress and answer prompts; destructive ones
(`uninstall`, `reset`) confirm first.

## Install it

```
omac launcher install    builds the palette + guides the one-time Raycast import
```

`launcher install` installs the extension's npm dependencies, then walks you through the import
(Raycast forbids scripting it):

1. `cd raycast/omac && npm run dev`
2. Leave it running until **omac** appears in Raycast, then press ⌃C — the imported command
   stays.
3. Trigger it any time by typing `omac` in Raycast.

Building needs Node (`omac software install` provides it). Check the state at any time:

```
omac launcher status
```

It reports `palette source` (is the extension present in this checkout) and `palette built`
(are its dependencies installed).

## Finding the omac binary

The extension locates `omac` by checking, in order: the **omac binary** path in its preferences
(⌘, in Raycast), then the usual install locations (`~/.local/bin`, Homebrew), then
`command -v omac` in a login shell. If your omac lives somewhere unusual, set the preference.

## Theming

The palette follows your omac theme: `omac theme set <name>` also pushes a matching palette to
Raycast (named **omac**) via Raycast's theme deeplink. Applying a custom palette requires
Raycast Pro. See [theme](theme.md).
