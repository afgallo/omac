# Window Management

omac's desktop is keyboard-first: [AeroSpace](https://nikitabobko.github.io/AeroSpace/) tiles
windows across 6 workspaces, and [SketchyBar](https://felixkratz.github.io/SketchyBar/) draws the
topbar. No second hotkey daemon — every binding lives in AeroSpace, and Raycast owns the
command-palette surface.

```bash
omac wm install   # deploy config, apply macOS tweaks, guided first-run
omac wm reload    # reload AeroSpace + SketchyBar
omac wm status    # show what is deployed / running / granted
```

## The modifier

The modifier is **Cmd**, chosen for muscle-memory parity with Omarchy's `SUPER` map. AeroSpace
registers only the specific Cmd combos below as global hotkeys — every unbound Cmd combo
(Cmd+C/V/T/W…) stays native to the focused app.

## Focus & move

| Keys | Action |
|---|---|
| `Cmd`+`Shift`+`H` / `J` / `K` / `L` | Focus left / down / up / right |
| `Cmd`+`Alt`+`H` / `J` / `K` / `L` | Move window left / down / up / right |

## Layout

| Keys | Action |
|---|---|
| `Cmd`+`/` | Toggle tiles ↔ accordion |
| `Cmd`+`,` | Toggle floating ↔ tiling |
| `Cmd`+`F` | macOS native fullscreen |
| `Cmd`+`Q` | Close window |
| `Cmd`+`R` | Enter resize mode |

## Workspaces

| Keys | Action |
|---|---|
| `Cmd`+`1`…`6` | Switch to workspace 1–6 |
| `Cmd`+`Shift`+`1`…`6` | Move window to workspace 1–6 |

## Launch

| Keys | Opens |
|---|---|
| `Cmd`+`Enter` | Ghostty (new window) |
| `Cmd`+`Shift`+`B` | Safari |
| `Cmd`+`Shift`+`N` | Visual Studio Code |
| `Cmd`+`Shift`+`O` | Obsidian |
| `Cmd`+`Shift`+`S` / `M` / `G` | Slack / Spotify / Signal |
| `Cmd`+`Shift`+`A` / `C` | ChatGPT / Claude (web) |
| `Cmd`+`Shift`+`E` / `Y` / `X` | HEY / YouTube / X (web) |
| `Cmd`+`Shift`+`P` | Interactive screenshot |

## Topbar

SketchyBar renders workspace pills, a clock, and a battery indicator. Each workspace shows its
number plus a Nerd Font glyph for every app with a window there; the focused workspace is a
filled accent pill, and empty workspaces dim out. Battery and clock carry their own icons, and
the battery glyph tracks the charge level (turning red when low, accent-colored while charging).
All colors are owned by the [theme](../themes/index.md) layer, so the bar recolors with every
`omac theme set`.
