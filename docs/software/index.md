# Software

omac installs your toolchain from declarative manifests, so a machine is reproducible and every
install is idempotent. Groups are opt-in / opt-out — install everything or a single group.

```bash
omac software install          # all groups
omac software install shell    # just one group
omac software list             # groups and their status
```

## Groups

Each group is a Brewfile under `software/groups/`.

| Group | Contents (highlights) |
|---|---|
| `ai` | `claude-code`, `opencode`, LM Studio |
| `shell` | `fzf`, `zoxide`, `ripgrep`, `bat`, `eza`, `fd`, `git-delta`, `starship`, `jq`, `tree`, `fastfetch`, `awscli` |
| `ides` | Visual Studio Code, Cursor, Zed, Neovim + [LazyVim](https://www.lazyvim.org) |
| `tuis` | `tmux`, `lazygit`, `lazydocker`, `htop`, `pgcli` |
| `guis` | Obsidian, Typora, LocalSend, mpv, Flameshot, **Ghostty** (default terminal), **Raycast** |
| `fonts` | JetBrainsMono, FiraCode, Hack, CaskaydiaCove — all Nerd Fonts |

The `ides` group installs the Neovim binary; the [LazyVim](https://www.lazyvim.org) base
config is scaffolded by the [theme engine](../themes/index.md) the first time a theme is
applied. Alongside the colorscheme each theme ships, omac drops two owned plugin specs
so the scaffolded editor works out of the box rather than as a bare starter:

- `omac/extras.lua` — LazyVim extras: language stacks (LSP + treesitter + formatter +
  linter) for the runtimes omac installs (Go, Ruby, Python, TS/JS) plus JSON, YAML,
  Docker and Markdown, and Prettier/ESLint. Imported from `lua/config/lazy.lua`
  between `lazyvim.plugins` and your own plugins — the order LazyVim requires.
- `omac-dx.lua` — cross-cutting tooling: tmux-aware pane navigation and a Bash
  language server.

All three (`omac-theme.lua`, `omac-dx.lua`, `omac/extras.lua`) are symlinks omac owns and
refreshes on upgrade. This is non-destructive — if you already have an nvim config, omac
leaves it untouched and just drops these clearly-named files in (LazyVim merges specs,
so your own config still wins where it overlaps).

## Runtimes

Language runtimes are managed by [`mise`](https://mise.jdx.dev) from
`software/runtimes.manifest`:

```
node@lts
python@3.13
go@1.24
ruby@3.4
bun@latest
deno@latest
```
