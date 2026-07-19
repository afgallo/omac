# First run

After installing, open a new terminal and check the install:

```bash
omac doctor
```

`doctor` checks the omac install for problems. From there, bring the desktop up in the order the
modules build on each other:

```bash
omac software install     # curated Homebrew groups + mise runtimes
omac shell install        # wire zsh/bash aliases, tools, and the Starship prompt
omac wm install           # AeroSpace + JankyBorders + macOS tweaks (guided)
omac launcher install     # free ⌘Space and set up Raycast (guided)
omac theme install        # wire apps, pre-install extensions, set the default theme
omac theme set kanagawa   # switch the whole desktop to a theme
```

!!! note "GUI permission grants"
    `wm` and `launcher` involve steps a piped installer cannot do for you — granting
    **Accessibility** and **Screen Recording** permissions, and freeing **⌘Space**. Those
    commands hand-hold you through the GUI-only parts. On **macOS 26 (Tahoe)** you must free
    ⌘Space by hand — see [launcher](../commands/launcher.md#freeing-space-on-macos-26-tahoe).

Run `omac help` any time to list every command.
