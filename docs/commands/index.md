# Commands

omac is a single dispatcher, `omac <command> [<subcommand>] [args]`. Commands live in
`cmd/*.zsh`; nested subcommands in `cmd/<command>/<sub>.zsh`. Run `omac help` to list them, or
`omac <command>` with no subcommand to print that command's usage.

| Command | What it does |
|---|---|
| [`install`](install.md) | Install or repair the omac CLI, shell integration, and base config |
| [`software`](software.md) | Install curated software groups (brew + mise) |
| [`shell`](shell.md) | Configure the interactive shell (aliases, tools, Starship prompt) |
| [`wm`](wm.md) | Configure the desktop (AeroSpace + JankyBorders) and apply macOS tweaks |
| [`theme`](theme.md) | Switch the desktop theme (terminal, editor, window borders, wallpaper) |
| [`wallpaper`](wallpaper.md) | Cycle the desktop wallpaper within the current theme |
| [`font`](font.md) | Switch the mono font across the terminal (and its TUIs) and editors |
| [`launcher`](launcher.md) | Guide Raycast first-run (free ⌘Space, hand-hold GUI steps) |
| [`update`](update.md) | Update omac (git pull, brew bundle, run migrations) |
| [`doctor`](doctor.md) | Check the omac install for problems |
| [`uninstall`](uninstall.md) | Remove the CLI symlink, shell integration, and (optionally) config |
| [`version` & `path`](misc.md) | Print the version and the resolved omac directories |
