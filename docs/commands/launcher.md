# omac launcher

Set up Raycast as the keyboard launcher — frees ⌘Space and hand-holds the GUI-only steps.

```
omac launcher install   free ⌘Space + guided Raycast first-run + build the palette
omac launcher status    show Raycast install/run state, ⌘Space, and palette build
```

`omac launcher install` opens Raycast and the relevant System Settings panes, builds the
[command palette](palette.md), then walks you through the parts macOS and Raycast forbid
scripting:

1. **Set the Raycast hotkey to ⌘Space** — Raycast binds itself to ⌥Space on a fresh
   install, so ⌘Space does nothing until you rebind it in **Raycast → Settings → General →
   Raycast Hotkey**.
2. **Enable Clipboard History** (and give it a hotkey) in Raycast's settings.
3. **Grant Raycast Accessibility** in **System Settings → Privacy & Security → Accessibility**.

## Freeing ⌘Space on macOS 26 (Tahoe)

!!! warning "⌘Space still opens Spotlight after install"
    macOS 26 ignores the `com.apple.symbolichotkeys` preference that older releases used to
    disable Spotlight, so omac cannot free ⌘Space for you — the live shortcut keeps opening
    Spotlight even when `omac launcher status` reports it freed. Disable it by hand:

    1. **System Settings → Keyboard → Keyboard Shortcuts → Spotlight** → uncheck
       **"Show Spotlight search"** (the ⌘Space row).
    2. **Raycast → Settings → General → Raycast Hotkey** → click the field and press **⌘Space**.

    If Raycast refuses ⌘Space with "already in use", the window server hasn't picked up the
    change yet — log out and back in once, then set the hotkey.

## What owns what

Raycast setup is split across modules: `software` installs the Raycast cask, `theme`
paints its palette (via `omac theme set`), and `launcher` handles first-run activation and
builds the [command palette](palette.md) — it deploys nothing else on disk.
