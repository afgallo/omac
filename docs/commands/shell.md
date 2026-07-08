# omac shell

Configure the interactive shell: modern aliases, tool integrations, and the Starship prompt.

```
omac shell install   wire ~/.zshrc + ~/.bashrc, seed Starship, wire tmux, paint the palette
omac shell status    show which shells (and tmux) are wired
```

`software` installs the CLI layer (Starship, zoxide, fzf, eza, bat, fd, ripgrep, mise, tmux); `shell`
is what makes a new terminal actually *use* it. It adds one idempotent managed block to each of
`~/.zshrc` and `~/.bashrc`:

```zsh
# >>> omac >>>
source "$OMAC_HOME/shell/omac.zsh"
# <<< omac <<<
```

The block sources omac's fragment straight from the repo, so `omac update` (git pull) refreshes
your shell config with no re-wire. Everything is guarded with `command -v`, so the fragment is
safe to source before `omac software install` has run — it lights up whatever is installed.

## What you get

- **Starship** as the default prompt, colored by the active omac theme.
- **Modern replacements** — `ls`→eza, `cat`→bat, `cd`→zoxide (frecency jumps), `find`→fd,
  `grep`→ripgrep, `vim`→nvim, plus `lg`=lazygit and a set of `g*` git shortcuts.
- **fzf** key bindings + completion, backed by fd.
- **mise** runtime activation.
- Sensible zsh/bash defaults: large de-duplicated shared history, case-insensitive
  menu completion, `autocd`, recursive `**` globbing.

Edit `shell/shared.sh` (both shells), `shell/omac.zsh`, or `shell/omac.bash` to customize; your
edits survive updates because omac only manages the marked block in your rc files.

## tmux

`shell install` also wires **tmux**: it adds one managed block to `~/.config/tmux/tmux.conf` that
sources omac's base config (`shell/tmux.conf`) straight from the repo — so `omac update` refreshes
it, and anything else you add to `tmux.conf` is left alone.

```tmux
# >>> omac >>>
source-file $OMAC_HOME/shell/tmux.conf
# <<< omac <<<
```

The base config ports a keyboard-driven setup (prefix `C-a`; `|`/`-` splits that keep the current
path; vi-style pane resize `h/j/k/l` and zoom `m`; mouse; vi copy mode that yanks to the macOS
clipboard; status line on top). It also declares its plugins for **TPM**, which omac clones and
installs **headlessly** on `shell install` (no manual `prefix + I`):

- **vim-tmux-navigator** — `Ctrl-h/j/k/l` moves seamlessly across tmux panes *and* nvim splits
  (the nvim half ships in omac's [nvim DX layer](software.md)).
- **tmux-resurrect** + **tmux-continuum** — save/restore sessions, autosaved every 10 minutes and
  restored on start.

The theme is omac's job, not a plugin: `omac theme set <name>` renders the status-line colors from
the theme's `colors.toml` into `~/.config/tmux/omac-theme.conf` (sourced by the base config) and
re-sources it into any running server, so tmux recolors live with the rest of the desktop.

## Starship theming

Starship is wired into the [theme engine](../themes/index.md): `omac theme set <name>` rewrites
the managed `[palettes.omac]` block in `~/.config/starship.toml` from the theme's `colors.toml`,
so the prompt recolors with the rest of the desktop. omac seeds `starship.toml` once and never
overwrites it — only that palette block is managed.
