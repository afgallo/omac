# Themes

A theme in omac is a whole-desktop palette. `omac theme set <name>` repoints the active-theme
symlink, renders the palette-derived macOS targets from templates, and reloads each app — so your
terminal, editor, topbar, and wallpaper change together, instantly.

## Bundled themes

omac ships 10 themes ported from Omarchy:

| Theme | | Theme | |
|---|---|---|---|
| `catppuccin` | | `kanagawa` | |
| `catppuccin-latte` | ☾ light | `nord` | |
| `everforest` | | `ristretto` | |
| `ethereal` | | `rose-pine` | |
| `gruvbox` | | `tokyo-night` | |

`omac theme list` marks the current theme with ● and light themes with ☾.

## Switching

```bash
omac theme list            # see what is bundled
omac theme set tokyo-night # switch everything at once
omac theme current         # print the active theme
omac theme reload          # re-apply after editing a config
```

## How a theme propagates

Each `themes/<name>/` directory holds two things:

- **Ported per-app files** — ready-made configs for apps that Omarchy already themed (Ghostty,
  Neovim (as [LazyVim](https://www.lazyvim.org)), btop, bat, delta, starship, lazygit, wallpaper,
  and more). These drop in almost unchanged.
- **A `colors.toml` palette** — for the targets Omarchy never had (macOS light/dark appearance,
  SketchyBar, Raycast, AeroSpace accent/border colors), omac *derives* the config from this
  palette through a templating seam. Nothing to hand-port.

This hybrid — file-per-app where a port exists, palette-derived where it does not — is the heart
of omac. See [Architecture](../architecture/index.md#the-theme-seam) for the mechanics.
