# omac font

Switch the mono font everywhere at once — Ghostty (and every terminal TUI it hosts:
Neovim, htop, lazygit, bat…) plus VS Code and Cursor. The font seam is **orthogonal to
the theme seam**: changing the font never touches colors, and `omac theme set` never
touches the typeface.

```
omac font set <name> [size]   switch font (bundled slug or any family), optional size
omac font list                list bundled fonts (● current)
omac font current             print the active font
omac font reload              re-apply the current font
```

## Fonts

`<name>` is either a bundled slug or **any font-family string** (passthrough). The bundled
Nerd Fonts are installed by `omac software install` (group `fonts`):

| Slug | Family |
|---|---|
| `jetbrains-mono` | JetBrainsMono Nerd Font (default) |
| `fira-code` | FiraCode Nerd Font |
| `hack` | Hack Nerd Font |
| `caskaydia-cove` | CaskaydiaCove Nerd Font |

```
omac font set fira-code        # a bundled font
omac font set hack 14          # …with a point size
omac font set "Comic Code"     # any installed family (passthrough)
```

The optional size applies to Ghostty and the editors; omit it to keep the current size.

## How it applies

- **Ghostty** renders `~/.config/ghostty/omac-font.conf` (family + size) and reloads live
  via `SIGUSR2`; every terminal TUI inherits the terminal font.
- **VS Code / Cursor** get `editor.fontFamily`, `terminal.integrated.fontFamily`, and
  `editor.fontSize` in `settings.json`, applied live.

The choice persists in `~/.config/omac/config.zsh` (`OMAC_ACTIVE_FONT`,
`OMAC_ACTIVE_FONT_SIZE`), alongside the active theme.
