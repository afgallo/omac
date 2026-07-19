# Themes

A theme in omac is a whole-desktop palette. `omac theme set <name>` repoints the active-theme
symlink, renders the palette-derived macOS targets from templates, and reloads each app — so your
terminal, editor, window borders, and wallpaper change together, instantly.

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
  Neovim (as [LazyVim](https://www.lazyvim.org)), bat, delta, lazygit, wallpaper,
  and more). These drop in almost unchanged. Apps that ship their own builtin themes
  (Ghostty, bat, [opencode](https://opencode.ai)) are pointed at the matching builtin by
  name via each theme's `apps.toml` — opencode falls back to its `system` theme (following
  the macOS light/dark omac sets) for palettes with no builtin match.
- **A `colors.toml` palette** — for the targets Omarchy never had a per-app file for (macOS
  light/dark appearance, JankyBorders, the [Starship](../commands/shell.md#starship-theming) prompt,
  Raycast, AeroSpace accent/border colors, and the tmux status line), omac *derives* the config
  from this palette through a templating seam. Nothing to hand-port. tmux status colors are
  re-sourced into any running server, so a theme switch recolors tmux live.

This hybrid — file-per-app where a port exists, palette-derived where it does not — is the heart
of omac. See [Architecture](../architecture/index.md#the-theme-seam) for the mechanics.

!!! note "Raycast palette needs Raycast Pro"
    Unlike the other targets, Raycast has no on-disk config to render — omac applies the palette
    through Raycast's `raycast://theme` import deeplink under a stable theme named **omac**.
    Custom themes are a **Raycast Pro** feature, so on a free plan the theme is sent but Raycast
    declines to apply it. This step is best-effort: `omac theme set` skips it silently when
    Raycast isn't installed and never fails the switch over it.

## Wallpapers

Each theme carries one or more images in `themes/<name>/backgrounds/`, named by convention:

```
NN-name.ext        # zero-padded from 01
```

`01-` is the theme's **default** wallpaper — `omac theme set` applies the first file
alphabetically, so `01-` always wins. Add extras as `02-`, `03-`, … When adding or
reordering images, keep the numbering contiguous and make sure `01-` is the image that best
represents the palette.

Cycle among a theme's backgrounds with [`omac wallpaper`](../commands/wallpaper.md):

```
omac wallpaper next      # apply the next background (wraps last → 01-)
omac wallpaper list      # list this theme's backgrounds (● current)
omac wallpaper current   # print the active wallpaper
```

The active choice is remembered (`OMAC_ACTIVE_WALLPAPER` in `~/.config/omac/config.zsh`);
`omac theme set` resets it to the new theme's `01-` default.
