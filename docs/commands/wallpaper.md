# omac wallpaper

Cycle the desktop wallpaper among the backgrounds bundled with the **current theme**.

```
omac wallpaper next      apply the next background for the current theme (wraps)
omac wallpaper list      list the current theme's backgrounds (● current)
omac wallpaper current   print the active wallpaper
```

Each theme ships one or more images in `themes/<name>/backgrounds/`, named `NN-name.ext`
(see [Themes › Wallpapers](../themes/index.md#wallpapers)). `omac wallpaper next` walks that
list in numeric order and wraps from the last back to `01-`. A theme with a single background
has nothing to cycle, so `next` is a friendly no-op.

The active choice is remembered in `~/.config/omac/config.zsh` (`OMAC_ACTIVE_WALLPAPER`).
Switching themes with [`omac theme set`](theme.md) resets the selection to that theme's `01-`
default, so cycling always starts from the palette's signature image.
