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
| `shell` | `fzf`, `zoxide`, `ripgrep`, `bat`, `eza`, `fd`, `git-delta`, `starship` |
| `ides` | Visual Studio Code, Cursor, Zed |
| `tuis` | `lazygit`, `lazydocker`, `btop`, `pgcli` |
| `guis` | Obsidian, Typora, LocalSend, mpv, Pixelmator Pro, **Ghostty** (default terminal), **Raycast** |
| `fonts` | JetBrainsMono, FiraCode, Hack, CaskaydiaCove — all Nerd Fonts |

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
