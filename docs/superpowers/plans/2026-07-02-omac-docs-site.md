# omac Documentation Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Material for MkDocs documentation site (hosted on GitHub Pages) and a rewritten repository `README.md` for omac.

**Architecture:** Authored Markdown lives under `docs/` and is built by Material for MkDocs from a single root `mkdocs.yml`. The existing `docs/superpowers/` specs/plans are excluded from the build via `exclude_docs`. A GitHub Actions workflow builds with `mkdocs build --strict` and deploys through the official Pages actions (Pages-from-Actions, no `gh-pages` branch). The README is a concise landing page that links out to the site.

**Tech Stack:** Material for MkDocs (Python), GitHub Actions, GitHub Pages, asciinema-player (self-hosted assets).

## Global Constraints

- Platform facts (copy verbatim where relevant): **Apple Silicon (arm64) only**; **macOS Sonoma 14, Sequoia 15, Tahoe 26** (numbering jumped 15→26); Homebrew prefix always `/opt/homebrew`.
- Install one-liner (copy verbatim): `curl -fsSL https://raw.githubusercontent.com/afgallo/omac/main/boot.sh | zsh`
- Repo/site: repo `github.com/afgallo/omac`; site `https://afgallo.github.io/omac`; `CNAME`-ready for `omac.dev` (not yet active).
- The 10 bundled themes (exact dir names): `catppuccin`, `catppuccin-latte`, `everforest`, `ethereal`, `gruvbox`, `kanagawa`, `nord`, `ristretto`, `rose-pine`, `tokyo-night`.
- Six software groups: `ai`, `shell`, `ides`, `tuis`, `guis`, `fonts`; runtimes via `mise` from `software/runtimes.manifest`.
- WM modifier is **Cmd** (AeroSpace bindings); 6 workspaces.
- Do **not** modify anything under `docs/superpowers/`. Do **not** add or change shell code in `bin/`, `cmd/`, `lib/`; this is a docs-only change. The zsh test suite (`test/run.zsh`) must remain green (it is untouched).
- Every task's verification is `mkdocs build --strict` passing (fails on broken links / pages-not-in-nav) plus a visual check via `mkdocs serve`.
- Commit after each task. Work on branch `docs/site`.

---

## File Structure

**Create:**
- `mkdocs.yml` — site config + theme + nav (root).
- `docs-requirements.txt` — pinned Python deps.
- `docs/index.md` — home / landing (asciinema embed).
- `docs/getting-started/{requirements,install,first-run}.md`
- `docs/commands/{index,install,software,wm,theme,launcher,update,doctor,uninstall,misc}.md`
- `docs/themes/index.md`
- `docs/software/index.md`
- `docs/window-management/index.md`
- `docs/architecture/index.md`
- `docs/contributing/index.md`
- `docs/assets/` — asciinema-player CSS/JS + `omac-theme.cast` (placeholder) + `extra.css`.
- `.github/workflows/docs.yml` — build + Pages deploy.

**Modify:**
- `README.md` — rewrite from 3 lines to a landing page.
- `.gitignore` — add `site/` (MkDocs build output). Create the file if absent.

**Do not touch:** `docs/superpowers/**`, `bin/`, `cmd/`, `lib/`, `test/`, `boot.sh`.

---

## Task 1: Scaffold MkDocs (config, deps, full stub tree, green build)

**Files:**
- Create: `docs-requirements.txt`, `mkdocs.yml`, `.gitignore` (or modify), and every page listed under "Create" above as a **stub** (single H1 + one-line intro).
- Create: `docs/assets/extra.css` (empty for now, referenced by config).

**Interfaces:**
- Produces: the complete `nav` in `mkdocs.yml` (later tasks fill page bodies, not nav); the `docs_dir: docs` + `exclude_docs: superpowers/` contract; theme/palette/font settings later tasks rely on.

- [ ] **Step 1: Create `docs-requirements.txt`**

```
mkdocs-material==9.5.39
```

- [ ] **Step 2: Create/append `.gitignore`**

Ensure it contains:

```
site/
.venv/
__pycache__/
```

- [ ] **Step 3: Create `mkdocs.yml`**

```yaml
site_name: omac
site_description: Omarchy-style, keyboard-driven, fully-themed desktop for macOS.
site_url: https://afgallo.github.io/omac/
repo_url: https://github.com/afgallo/omac
repo_name: afgallo/omac
copyright: Built for macOS on Apple Silicon.

docs_dir: docs
exclude_docs: |
  superpowers/

theme:
  name: material
  font:
    text: Inter
    code: JetBrains Mono
  icon:
    repo: fontawesome/brands/github
  palette:
    - media: "(prefers-color-scheme)"
      toggle:
        icon: material/brightness-auto
        name: Follow system
    - media: "(prefers-color-scheme: light)"
      scheme: default
      primary: black
      accent: amber
      toggle:
        icon: material/weather-sunny
        name: Light
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      primary: black
      accent: amber
      toggle:
        icon: material/weather-night
        name: Dark
  features:
    - navigation.instant
    - navigation.sections
    - navigation.top
    - navigation.footer
    - search.suggest
    - search.highlight
    - content.code.copy
    - content.code.annotate
    - toc.follow

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.highlight:
      anchor_linenums: true
  - attr_list
  - md_in_html
  - toc:
      permalink: true

extra_css:
  - assets/extra.css

nav:
  - Home: index.md
  - Getting Started:
      - Requirements: getting-started/requirements.md
      - Install: getting-started/install.md
      - First run: getting-started/first-run.md
  - Commands:
      - Overview: commands/index.md
      - install: commands/install.md
      - software: commands/software.md
      - wm: commands/wm.md
      - theme: commands/theme.md
      - launcher: commands/launcher.md
      - update: commands/update.md
      - doctor: commands/doctor.md
      - uninstall: commands/uninstall.md
      - version & path: commands/misc.md
  - Themes: themes/index.md
  - Software: software/index.md
  - Window Management: window-management/index.md
  - Architecture: architecture/index.md
  - Contributing: contributing/index.md
```

- [ ] **Step 4: Create every page as a stub**

Each file gets a real H1 and one-line intro so `--strict` (which flags empty/not-in-nav pages) stays green. Example for `docs/index.md`:

```markdown
# omac

Omarchy-style, keyboard-driven, fully-themed desktop for macOS. *(page content added in a later task)*
```

Create the analogous one-H1 stub for: `getting-started/requirements.md` (`# Requirements`), `getting-started/install.md` (`# Install`), `getting-started/first-run.md` (`# First run`), `commands/index.md` (`# Commands`), `commands/install.md` (`# omac install`), `commands/software.md` (`# omac software`), `commands/wm.md` (`# omac wm`), `commands/theme.md` (`# omac theme`), `commands/launcher.md` (`# omac launcher`), `commands/update.md` (`# omac update`), `commands/doctor.md` (`# omac doctor`), `commands/uninstall.md` (`# omac uninstall`), `commands/misc.md` (`# omac version & path`), `themes/index.md` (`# Themes`), `software/index.md` (`# Software`), `window-management/index.md` (`# Window Management`), `architecture/index.md` (`# Architecture`), `contributing/index.md` (`# Contributing`).

- [ ] **Step 5: Create `docs/assets/extra.css`** (empty placeholder)

```css
/* omac docs — custom overrides added in the visual-polish task */
```

- [ ] **Step 6: Install deps and build strict**

Run:
```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r docs-requirements.txt
mkdocs build --strict
```
Expected: `INFO - Documentation built in …` with **no** WARNING lines (strict turns warnings into failures). If a "page exists but not in nav" or "unable to load" error appears, fix the offending path.

- [ ] **Step 7: Serve and eyeball**

Run: `mkdocs serve`
Expected: `http://127.0.0.1:8000` renders; every nav entry loads; palette toggle (auto/light/dark) is present in the header; search works. Stop with Ctrl-C.

- [ ] **Step 8: Commit**

```bash
git add mkdocs.yml docs-requirements.txt .gitignore docs/
git commit -m "docs(site): scaffold Material for MkDocs skeleton + nav"
```

---

## Task 2: GitHub Pages deploy workflow

**Files:**
- Create: `.github/workflows/docs.yml`

**Interfaces:**
- Consumes: `docs-requirements.txt`, `mkdocs.yml` from Task 1.
- Produces: a `main`-push deploy to Pages; assumes repo Pages source is set to "GitHub Actions".

- [ ] **Step 1: Create `.github/workflows/docs.yml`**

```yaml
name: docs

on:
  push:
    branches: [main]
    paths:
      - "docs/**"
      - "mkdocs.yml"
      - "docs-requirements.txt"
      - ".github/workflows/docs.yml"
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -r docs-requirements.txt
      - run: mkdocs build --strict
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: Validate YAML locally**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/docs.yml')); print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/docs.yml
git commit -m "docs(ci): build and deploy site to GitHub Pages via Actions"
```

- [ ] **Step 4: Document the one-time manual toggle (no code)**

Record in the PR description / hand to the user: In **repo Settings → Pages → Build and deployment → Source**, select **GitHub Actions**. This cannot be done from code and must be set once before the first deploy succeeds. (Custom domain `omac.dev` is added later in this same Pages screen + a `docs/CNAME` file.)

---

## Task 3: Home page + asciinema embed infrastructure

**Files:**
- Modify: `docs/index.md`
- Create: `docs/assets/asciinema-player.min.css`, `docs/assets/asciinema-player.min.js`, `docs/assets/omac-theme.cast` (placeholder)
- Modify: `mkdocs.yml` (add `extra_javascript` + player init)

**Interfaces:**
- Consumes: theme/nav from Task 1.
- Produces: a reusable asciinema embed pattern; the placeholder `.cast` path `docs/assets/omac-theme.cast` that a real recording later overwrites.

- [ ] **Step 1: Vendor the asciinema-player assets**

Run:
```bash
curl -fsSL https://cdn.jsdelivr.net/npm/asciinema-player@3.8.0/dist/bundle/asciinema-player.min.js -o docs/assets/asciinema-player.min.js
curl -fsSL https://cdn.jsdelivr.net/npm/asciinema-player@3.8.0/dist/bundle/asciinema-player.css -o docs/assets/asciinema-player.min.css
```
Expected: both files non-empty (`ls -la docs/assets/`).

- [ ] **Step 2: Create a placeholder cast** `docs/assets/omac-theme.cast`

This is a minimal valid asciicast v2 file so the player renders until the real recording replaces it:

```
{"version": 2, "width": 80, "height": 6, "title": "omac theme set (placeholder)"}
[0.5, "o", "$ omac theme set kanagawa\r\n"]
[1.0, "o", "→ rendering palette targets…\r\n"]
[1.6, "o", "✓ theme set: kanagawa\r\n"]
[2.4, "o", "$ \r\n"]
[3.5, "o", ""]
```

- [ ] **Step 3: Wire player assets in `mkdocs.yml`**

Add to `extra_css` (append under the existing entry) and add a new `extra_javascript` block:

```yaml
extra_css:
  - assets/extra.css
  - assets/asciinema-player.min.css

extra_javascript:
  - assets/asciinema-player.min.js
  - assets/player-init.js
```

- [ ] **Step 4: Create `docs/assets/player-init.js`**

```javascript
// Mount an asciinema player into any <div data-cast="…"> on the page.
function omacMountCasts() {
  document.querySelectorAll("[data-cast]").forEach(function (el) {
    if (el.dataset.mounted) return;
    el.dataset.mounted = "1";
    AsciinemaPlayer.create(el.dataset.cast, el, {
      autoPlay: true, loop: true, idleTimeLimit: 2, poster: "npt:0:2", fit: "width"
    });
  });
}
document.addEventListener("DOMContentLoaded", omacMountCasts);
document.addEventListener("DOMContentSwitch", omacMountCasts); // navigation.instant
```

- [ ] **Step 5: Write `docs/index.md`**

```markdown
# omac

**Omarchy-style, keyboard-driven, fully-themed desktop for macOS.**

One command restyles your terminal, editor, topbar, and wallpaper. Tiling and workspaces are
keyboard-native. Your whole toolchain installs from declarative manifests. omac is a *layer on
top of* macOS — not a distro — so it runs safely on your existing Mac.

<div data-cast="assets/omac-theme.cast" style="max-width:760px;margin:1.5rem 0;"></div>

```bash
curl -fsSL https://raw.githubusercontent.com/afgallo/omac/main/boot.sh | zsh
```

## What you get

- **One-command theming** — `omac theme set <name>` propagates a palette to every app at once.
- **Keyboard-driven desktop** — AeroSpace tiling + 6 workspaces + a SketchyBar topbar.
- **Declarative software** — curated Homebrew groups and `mise` runtimes, opt-in / opt-out.
- **Idempotent installer** — a re-entrant `git`-clone bootstrap you can re-run any time.
- **10 bundled themes** — ported from Omarchy, plus palette-derived macOS targets.

## Requirements

Apple Silicon (arm64) · macOS Sonoma 14, Sequoia 15, or Tahoe 26.

[Get started →](getting-started/requirements.md){ .md-button .md-button--primary }
[Browse the commands →](commands/index.md){ .md-button }

!!! note "The demo above is a placeholder"
    The real `omac theme set` cast is recorded on an installed machine — see
    [Contributing](contributing/index.md#recording-the-demo).
```

- [ ] **Step 6: Build strict + serve**

Run: `mkdocs build --strict && mkdocs serve`
Expected: no warnings; home page shows the player box (placeholder cast loops) and both buttons.

- [ ] **Step 7: Commit**

```bash
git add docs/index.md docs/assets/ mkdocs.yml
git commit -m "docs(site): home page with asciinema demo scaffold"
```

---

## Task 4: Getting Started section

**Files:**
- Modify: `docs/getting-started/requirements.md`, `install.md`, `first-run.md`

- [ ] **Step 1: Write `docs/getting-started/requirements.md`**

```markdown
# Requirements

omac targets one platform on purpose, so everything it does can assume a known environment.

| Requirement | Value |
|---|---|
| Architecture | Apple Silicon (arm64) only — Homebrew prefix is always `/opt/homebrew` |
| macOS | Sonoma **14**, Sequoia **15**, or Tahoe **26** (Apple's numbering jumped 15→26) |
| Provisioned for you | Xcode Command Line Tools, Homebrew |
| You provide | An internet connection and admin rights |

!!! warning "Intel and older macOS are refused"
    The bootstrap preflight aborts on Intel Macs and on macOS older than 14. This is deliberate,
    not a limitation to work around.

A clean macOS install gives you the full pristine result on first run, but it is **recommended,
not required** — omac is idempotent and non-destructive (managed config blocks, confirm-before-
overwrite), so it is safe to run on an existing Mac.
```

- [ ] **Step 2: Write `docs/getting-started/install.md`**

```markdown
# Install

Run the bootstrap. It is safe to re-run — the same command installs or updates.

```bash
curl -fsSL https://raw.githubusercontent.com/afgallo/omac/main/boot.sh | zsh
```

## What the bootstrap does

1. **Preflight** — verifies macOS (Darwin), Apple Silicon, macOS 14+, and HTTPS reachability to
   github.com.
2. **Xcode Command Line Tools** — installs them if missing (rerun the bootstrap once they finish).
3. **Homebrew** — installs it if missing, then loads its shell environment.
4. **Clone or update** — clones the repo to `~/.local/share/omac`, or `git pull --ff-only`s an
   existing checkout (re-entrant; a half-finished clone is detected and offered a re-clone).
5. **Core install** — runs `omac install` to wire the CLI, shell integration, and base config.

When it finishes:

```
✓ omac installed. Open a new terminal, then run: omac doctor
```

!!! tip "Open a new terminal"
    Shell integration is picked up by new shells. Open a fresh terminal window before running
    `omac` commands.
```

- [ ] **Step 3: Write `docs/getting-started/first-run.md`**

```markdown
# First run

After installing, open a new terminal and check the install:

```bash
omac doctor
```

`doctor` checks the omac install for problems. From there, bring the desktop up in the order the
modules build on each other:

```bash
omac software install     # curated Homebrew groups + mise runtimes
omac wm install           # AeroSpace + SketchyBar + macOS tweaks (guided)
omac launcher install     # free ⌘Space and set up Raycast (guided)
omac theme install        # wire apps, pre-install extensions, set the default theme
omac theme set kanagawa   # switch the whole desktop to a theme
```

!!! note "GUI permission grants"
    `wm` and `launcher` involve steps a piped installer cannot do for you — granting
    **Accessibility** and **Screen Recording** permissions, and freeing **⌘Space**. Those
    commands hand-hold you through the GUI-only parts.

Run `omac help` any time to list every command.
```

- [ ] **Step 4: Build strict + commit**

Run: `mkdocs build --strict`
Expected: no warnings.
```bash
git add docs/getting-started/
git commit -m "docs(site): getting started (requirements, install, first run)"
```

---

## Task 5: Commands section

**Files:**
- Modify: `docs/commands/index.md` and the ten command pages.

Source of truth: each page mirrors the `# help:` header and the usage block the CLI itself prints (verified from `cmd/*.zsh`).

- [ ] **Step 1: Write `docs/commands/index.md`**

```markdown
# Commands

omac is a single dispatcher, `omac <command> [<subcommand>] [args]`. Commands live in
`cmd/*.zsh`; nested subcommands in `cmd/<command>/<sub>.zsh`. Run `omac help` to list them, or
`omac <command>` with no subcommand to print that command's usage.

| Command | What it does |
|---|---|
| [`install`](install.md) | Install or repair the omac CLI, shell integration, and base config |
| [`software`](software.md) | Install curated software groups (brew + mise) |
| [`wm`](wm.md) | Configure the desktop (AeroSpace + SketchyBar) and apply macOS tweaks |
| [`theme`](theme.md) | Switch the desktop theme (terminal, editor, topbar, wallpaper) |
| [`launcher`](launcher.md) | Guide Raycast first-run (free ⌘Space, hand-hold GUI steps) |
| [`update`](update.md) | Update omac (git pull, brew bundle, run migrations) |
| [`doctor`](doctor.md) | Check the omac install for problems |
| [`uninstall`](uninstall.md) | Remove the CLI symlink, shell integration, and (optionally) config |
| [`version` & `path`](misc.md) | Print the version and the resolved omac directories |
```

- [ ] **Step 2: Write `docs/commands/install.md`**

```markdown
# omac install

Install or repair the omac CLI, shell integration, and base config.

```bash
omac install
```

Idempotent: it wires the `omac` command onto your `PATH`, adds shell integration, and lays down
base config without clobbering existing files (managed blocks, confirm-before-overwrite). Run it
again any time to repair a broken install. This is the step the bootstrap runs for you at the end
of a fresh install.
```

- [ ] **Step 3: Write `docs/commands/software.md`**

```markdown
# omac software

Install curated software groups (brew + mise).

```
omac software install [group]   install all groups, or one
omac software list              list groups and their status
```

Groups: `ai`, `shell`, `ides`, `tuis`, `guis`, `fonts`. Each group is a Brewfile under
`software/groups/`; language runtimes come from `software/runtimes.manifest` via `mise`. See
[Software](../software/index.md) for what each group contains and the opt-in / opt-out model.
```

- [ ] **Step 4: Write `docs/commands/wm.md`**

```markdown
# omac wm

Configure the keyboard-driven desktop (AeroSpace + SketchyBar) and apply macOS tweaks.

```
omac wm install   deploy config, apply tweaks, guided first-run
omac wm reload    reload AeroSpace + SketchyBar config
omac wm status    show which components are deployed
```

See [Window Management](../window-management/index.md) for the full hotkey map and the topbar.
```

- [ ] **Step 5: Write `docs/commands/theme.md`**

```markdown
# omac theme

Switch among the bundled themes — terminal, editor, topbar, and wallpaper at once.

```
omac theme install       wire apps, pre-install extensions, set default
omac theme set <name>    switch to a bundled theme
omac theme list          list bundled themes (● current, ☾ light)
omac theme current       print the active theme
omac theme reload        re-apply the current theme
```

See [Themes](../themes/index.md) for the 10 bundled themes and how a theme propagates.
```

- [ ] **Step 6: Write `docs/commands/launcher.md`**

```markdown
# omac launcher

Set up Raycast as the keyboard launcher — frees ⌘Space and hand-holds the GUI-only steps.

```
omac launcher install   free ⌘Space + guided Raycast first-run
omac launcher status    show Raycast install/run state and ⌘Space
```
```

- [ ] **Step 7: Write `docs/commands/update.md`**

```markdown
# omac update

Update omac: `git pull`, `brew bundle`, and run any pending migrations.

```bash
omac update
```

Migrations are tracked in a ledger under `~/.local/state/omac/migrations`; a failed migration is
skipped into a separate ledger instead of blocking later ones. On a fresh install, existing
migrations are baselined as applied so a new machine never replays history.
```

- [ ] **Step 8: Write `docs/commands/doctor.md`**

```markdown
# omac doctor

Check the omac install for problems.

```bash
omac doctor
```

Run it right after installing (the bootstrap tells you to) and any time something seems off. It
reports on the CLI wiring, config, and the state of the managed components.
```

- [ ] **Step 9: Write `docs/commands/uninstall.md`**

```markdown
# omac uninstall

Remove the omac CLI symlink, shell integration, and (optionally) your config.

```bash
omac uninstall
```

Removes the managed pieces omac added. Your user config under `~/.config/omac` is removed only if
you opt in when prompted.
```

- [ ] **Step 10: Write `docs/commands/misc.md`**

```markdown
# omac version & path

## version

Print the omac version.

```bash
omac version
```

## path

Print the resolved omac directories — useful when debugging where omac reads and writes.

```bash
omac path
```

Prints `OMAC_HOME`, `OMAC_CONFIG`, `OMAC_STATE`, `themes`, `templates`, `current`, `profile`, and
the Homebrew `prefix`. These follow an XDG-on-macOS layout: repo at `~/.local/share/omac`, user
state at `~/.config/omac`, and the migration ledger at `~/.local/state/omac`.
```

- [ ] **Step 11: Build strict + commit**

Run: `mkdocs build --strict`
Expected: no warnings.
```bash
git add docs/commands/
git commit -m "docs(site): CLI command reference"
```

---

## Task 6: Themes page

**Files:**
- Modify: `docs/themes/index.md`

- [ ] **Step 1: Write `docs/themes/index.md`**

```markdown
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
  Neovim, btop, bat, delta, starship, lazygit, wallpaper, and more). These drop in almost
  unchanged.
- **A `colors.toml` palette** — for the targets Omarchy never had (macOS light/dark appearance,
  SketchyBar, Raycast, AeroSpace accent/border colors), omac *derives* the config from this
  palette through a templating seam. Nothing to hand-port.

This hybrid — file-per-app where a port exists, palette-derived where it does not — is the heart
of omac. See [Architecture](../architecture/index.md#the-theme-seam) for the mechanics.
```

- [ ] **Step 2: Build strict + commit**

Run: `mkdocs build --strict`
Expected: no warnings.
```bash
git add docs/themes/
git commit -m "docs(site): themes page"
```

---

## Task 7: Software page

**Files:**
- Modify: `docs/software/index.md`

- [ ] **Step 1: Write `docs/software/index.md`**

```markdown
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
```

- [ ] **Step 2: Build strict + commit**

Run: `mkdocs build --strict`
Expected: no warnings.
```bash
git add docs/software/
git commit -m "docs(site): software groups + runtimes page"
```

---

## Task 8: Window Management page

**Files:**
- Modify: `docs/window-management/index.md`

Source of truth: `wm/aerospace/aerospace.toml` (bindings transcribed verbatim below).

- [ ] **Step 1: Write `docs/window-management/index.md`**

```markdown
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

SketchyBar renders workspaces, a clock, and a battery indicator. Its colors are owned by the
[theme](../themes/index.md) layer, so it recolors with every `omac theme set`.
```

- [ ] **Step 2: Build strict + commit**

Run: `mkdocs build --strict`
Expected: no warnings.
```bash
git add docs/window-management/
git commit -m "docs(site): window management + hotkey map"
```

---

## Task 9: Architecture page

**Files:**
- Modify: `docs/architecture/index.md`

Source: distilled from `docs/superpowers/specs/2026-06-18-omac-design.md`.

- [ ] **Step 1: Write `docs/architecture/index.md`**

```markdown
# Architecture

omac reproduces the parts of Omarchy that matter most on macOS — keyboard navigation, tiling,
workspaces, and one-command theming — by assembling mature macOS tools and building the one piece
that does not exist on the Mac: a theme-orchestration layer. It is **not** a Linux-distro clone;
anything macOS already does natively (disk encryption, snapshots, firewall, Touch ID, OS install)
is deliberately out of scope.

## The dispatcher

`omac` is a single entrypoint (`bin/omac`) that resolves `omac <command> [<subcommand>]` to a
script: `cmd/<command>.zsh`, or `cmd/<command>/<subcommand>.zsh` for nested commands. Each command
carries a `# help:` header that `omac help` reads. Logic lives in namespaced engines under `lib/`;
the `cmd/` scripts stay thin.

## The five modules

Independent sub-projects, each with its own spec → plan → build cycle, built in order:

1. **bootstrap** — the installer and the `omac` CLI command center; updates and migrations.
2. **software** — declarative Brewfile groups + `mise` runtimes, opt-in / opt-out.
3. **wm** — AeroSpace + SketchyBar + the global hotkey map + macOS tweaks.
4. **launcher** — Raycast: app launch, command surface, clipboard history, snippets.
5. **theme** — the orchestration layer that ports the themes and derives the macOS targets.

## Canonical paths

omac uses an XDG-on-macOS layout (a deliberate choice to mirror Omarchy and lower porting
friction — not an oversight):

| Path | Side | Role |
|---|---|---|
| `~/.local/share/omac` | repo (read-only) | scripts, defaults, themes, templates, migrations |
| `~/.config/omac` | user state | `config.zsh`, overrides, selected theme |
| `~/.config/omac/current` | user state | symlink → active theme dir |
| `~/.local/state/omac/migrations` | user state | applied-migration ledger |

## Migrations

`omac update` runs pending migrations against a ledger. Fresh installs baseline existing
migrations as applied (so a new machine never replays history), and a failed migration is skipped
into a separate ledger rather than blocking later ones.

## The theme seam

The theme layer is hybrid: **file-per-app** where Omarchy already had a themed config (dropped in
almost unchanged), and **palette-derived** for the macOS-only targets Omarchy never had (macOS
light/dark appearance, SketchyBar, Raycast, AeroSpace colors), rendered from a small `colors.toml`
palette through a templating seam. `omac theme set` repoints the `current` symlink, re-renders the
derived targets, and reloads each app.

For the full design, see the specs under `docs/superpowers/specs/` in the repository.
```

- [ ] **Step 2: Build strict + commit**

Run: `mkdocs build --strict`
Expected: no warnings.
```bash
git add docs/architecture/
git commit -m "docs(site): architecture overview"
```

---

## Task 10: Contributing page (incl. recording the demo)

**Files:**
- Modify: `docs/contributing/index.md`

- [ ] **Step 1: Write `docs/contributing/index.md`**

```markdown
# Contributing

## Repository layout

```
bin/omac         # dispatcher entrypoint
boot.sh          # curl … | zsh bootstrap installer
cmd/             # one file per command; cmd/<x>/<sub>.zsh for nested subcommands
lib/             # namespaced engines (theme, wm, software, migrate, …)
software/        # Brewfile groups + runtimes.manifest
wm/              # aerospace.toml, sketchybar config + plugins, macOS tweaks
themes/          # bundled themes (per-app files + colors.toml)
templates/       # palette-rendered templates for macOS-only targets
migrations/      # ordered migration scripts
test/            # zsh test suite
docs/            # this documentation site (docs/superpowers/ = internal specs, unpublished)
```

## Running the tests

omac has a zsh test suite. Run the whole thing:

```bash
test/run.zsh
```

## Working on the docs site

The site is Material for MkDocs. Preview locally with live reload:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r docs-requirements.txt
mkdocs serve            # http://127.0.0.1:8000
mkdocs build --strict   # what CI runs; fails on broken links
```

Pushing to `main` rebuilds and publishes to GitHub Pages automatically. Internal design specs
under `docs/superpowers/` are excluded from the published site.

## Recording the demo

The home-page demo is an [asciinema](https://asciinema.org) cast. The committed
`docs/assets/omac-theme.cast` is a placeholder; record the real one on a machine with omac
installed:

```bash
asciinema rec docs/assets/omac-theme.cast \
  --title "omac theme set" --cols 80 --rows 12 --overwrite
# in the recording: run `omac theme set kanagawa`, then `omac theme set tokyo-night`,
# so the desktop visibly recolors. Press Ctrl-D to stop.
```

Commit the new `.cast` — the player picks it up with no other changes.

## Adding a theme

Add a `themes/<name>/` directory with the per-app files and a `colors.toml` palette, then
`omac theme list` and `omac theme set <name>` to verify. Add the name to the table in
[Themes](../themes/index.md).

## Adding a command

Add `cmd/<name>.zsh` with a `# help:` header and a usage block, plus a matching test under
`test/`. Nested subcommands go in `cmd/<name>/<sub>.zsh`. Document it under
[Commands](../commands/index.md).
```

- [ ] **Step 2: Build strict + commit**

Run: `mkdocs build --strict`
Expected: no warnings.
```bash
git add docs/contributing/
git commit -m "docs(site): contributing guide"
```

---

## Task 11: Rewrite README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Overwrite `README.md`**

```markdown
# omac

**Omarchy-style, keyboard-driven, fully-themed desktop for macOS.**

One command restyles your terminal, editor, topbar, and wallpaper. Tiling and workspaces are
keyboard-native. Your whole toolchain installs from declarative manifests. omac is a *layer on
top of* macOS — not a distro — so it runs safely on your existing Mac.

![Platform: Apple Silicon](https://img.shields.io/badge/platform-Apple%20Silicon-black)
![macOS 14+](https://img.shields.io/badge/macOS-Sonoma%2014%2B-black)
![Shell: zsh](https://img.shields.io/badge/shell-zsh-black)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/afgallo/omac/main/boot.sh | zsh
```

The bootstrap is idempotent: it preflights (Apple Silicon, macOS 14+), installs Xcode Command
Line Tools and Homebrew if missing, clones the repo, and wires the `omac` CLI. Then open a new
terminal and run `omac doctor`.

## What you get

- **One-command theming** — `omac theme set <name>` propagates a palette to every app at once.
- **Keyboard-driven desktop** — AeroSpace tiling + 6 workspaces + a SketchyBar topbar.
- **Declarative software** — curated Homebrew groups and `mise` runtimes, opt-in / opt-out.
- **Idempotent installer** — a re-entrant `git`-clone bootstrap you can re-run any time.
- **10 bundled themes** — catppuccin · catppuccin-latte · everforest · ethereal · gruvbox ·
  kanagawa · nord · ristretto · rose-pine · tokyo-night.

## Try it

```bash
omac software install       # curated Homebrew groups + mise runtimes
omac wm install             # AeroSpace + SketchyBar + macOS tweaks (guided)
omac theme set kanagawa     # recolor the whole desktop
omac help                   # list every command
```

## Documentation

**→ Full documentation: [afgallo.github.io/omac](https://afgallo.github.io/omac)**

Getting started, the complete CLI reference, the theme and hotkey guides, and the architecture.

## Development

```bash
test/run.zsh                # run the zsh test suite
mkdocs serve                # preview the docs site (see docs/contributing)
```

Design specs live under `docs/superpowers/specs/`.

## Requirements

Apple Silicon (arm64) · macOS Sonoma 14, Sequoia 15, or Tahoe 26. Requires an internet connection
and admin rights.
```

- [ ] **Step 2: Verify Markdown renders**

Run: `python3 -c "import pathlib; print('README bytes:', len(pathlib.Path('README.md').read_text()))"`
Expected: a non-trivial byte count (> 1000). Eyeball the file for correct headings and the docs link.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README as a landing page"
```

---

## Task 12: Visual polish + final strict pass

**Files:**
- Modify: `docs/assets/extra.css`, and `mkdocs.yml` if a logo is added.
- Create (optional): `docs/assets/logo.svg`, `docs/assets/favicon.svg`.

- [ ] **Step 1: Write `docs/assets/extra.css`**

```css
/* Warm terminal-rice accent tuning + roomier code blocks. */
:root {
  --md-code-font: "JetBrains Mono", monospace;
}

/* Tighten the hero buttons spacing on the home page. */
.md-button + .md-button { margin-left: 0.4rem; }

/* Give asciinema casts a subtle framed look that fits both palettes. */
[data-cast] {
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,0.25);
}
```

- [ ] **Step 2 (optional): Add a monogram logo/favicon**

If a quick SVG monogram is available, drop `docs/assets/logo.svg` and `docs/assets/favicon.svg`, then add under `theme:` in `mkdocs.yml`:

```yaml
  logo: assets/logo.svg
  favicon: assets/favicon.svg
```

Skip this step if no logo is ready — it is not a blocker.

- [ ] **Step 3: Final strict build + full serve review**

Run: `mkdocs build --strict`
Expected: `Documentation built` with **zero** warnings.
Then `mkdocs serve` and click through every nav entry: Home (player loops), Getting Started (3
pages), Commands (overview + 10 pages), Themes, Software, Window Management, Architecture,
Contributing. Toggle light/dark. Confirm search returns results for "theme" and "hotkey".

- [ ] **Step 4: Confirm the zsh suite is still green (docs changed nothing in it)**

Run: `test/run.zsh`
Expected: all tests pass (this change added no shell code).

- [ ] **Step 5: Commit**

```bash
git add docs/assets/ mkdocs.yml
git commit -m "docs(site): visual polish + final strict pass"
```

- [ ] **Step 6: Push and open a PR**

```bash
git push -u origin docs/site
gh pr create --fill --title "omac documentation site + README" \
  --body "Material for MkDocs site (GitHub Pages) + rewritten README. See docs/superpowers/specs/2026-07-02-omac-docs-site-design.md. NOTE: set repo Settings → Pages → Source to 'GitHub Actions' before first deploy."
```

---

## Self-Review Notes

- **Spec coverage:** tooling/deploy (Tasks 1–2), IA/all nav sections (Tasks 1, 4–10), README (Task 11), visual identity/palette/fonts (Tasks 1, 12), asciinema infra + placeholder + record instructions (Tasks 3, 10), `exclude_docs` + `--strict` (Task 1), testing/verification (every task + Task 12 Step 4). Covered.
- **Placeholder scan:** the only intentional placeholder is the asciinema `.cast`, explicitly scoped by the spec as a real-machine step; every doc page has complete, ready-to-commit content.
- **Consistency:** asset paths (`docs/assets/…`), the install one-liner, theme list, group list, and hotkeys are identical across README, home, and content pages, and match the source files.
```
