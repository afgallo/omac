# Window Management

omac's desktop is keyboard-first: [AeroSpace](https://nikitabobko.github.io/AeroSpace/) tiles
windows across 6 workspaces, and [JankyBorders](https://github.com/FelixKratz/JankyBorders)
draws a colored border around the focused window. omac stays native-first — the macOS menu bar
keeps clock, battery, Wi-Fi, notifications, and Control Center; omac adds only what the Mac
lacks. No second hotkey daemon — every binding lives in AeroSpace, and Raycast owns the
command-palette surface.

```bash
omac wm install   # deploy config, apply macOS tweaks, guided first-run
omac wm reload    # reload AeroSpace + borders
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

## Focus border

JankyBorders draws a border around the focused window so it is always obvious where keystrokes
go — the piece native macOS omits under tiling. The focused window gets an accent border;
unfocused windows get a faint one. Both colors are owned by the [theme](../themes/index.md)
layer (`active_color` = accent, `inactive_color` = a translucent foreground), so the border
recolors with every `omac theme set`. There is no custom top bar: the native macOS menu bar
keeps clock, battery, Wi-Fi, notifications, and Control Center. Workspaces have no on-screen
indicator by design — `Cmd`+`1`…`6` is deterministic, so you switch by muscle memory.

## Floating windows

Tiling is the default, but native dialogs and utility windows make no sense tiled, so AeroSpace
floats a starter set — System Settings, Activity Monitor, System Information, Calculator,
Archive Utility, the App Store, Raycast, and Screen Sharing. Add more with an
`[[on-window-detected]]` rule in `wm/aerospace/aerospace.toml`:

```toml
[[on-window-detected]]
if.app-id = 'com.apple.systempreferences'
run = 'layout floating'
```
