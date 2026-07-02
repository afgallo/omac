# omac — Documentation Site Design

**Status:** Approved design · **Date:** 2026-07-02 · **Audience:** engineers who run macOS

## What this is

A public documentation set for `omac`: a rewritten GitHub `README.md` that serves as the
repository landing page, and a full documentation site built with **Material for MkDocs** and
hosted on **GitHub Pages** at `https://afgallo.github.io/omac` (custom domain `omac.dev`
reserved for later — the setup is `CNAME`-ready so the switch is a one-line change).

The goal is documentation that matches the project's own aesthetic: keyboard-driven, cleanly
themed, code-forward, and elegant. The docs echo omac's identity — a light/dark palette toggle
that mirrors what `omac theme set` does to the desktop, JetBrains Mono for code (the font omac
installs), and instant search.

## Goals

- A README that reads as a proper landing page (tagline, install one-liner, feature list,
  command examples, theme strip) and links out to the full site — without duplicating it.
- A Material for MkDocs site covering: getting started, the full CLI reference, themes,
  software groups, window management, architecture, and contributing.
- Zero-friction deploy: every push to `main` rebuilds and publishes to GitHub Pages via a
  GitHub Action.
- Local authoring with live reload (`mkdocs serve`), documented for contributors.
- The internal `docs/superpowers/` specs and plans stay in the repo and history but are
  excluded from the published site.

## Non-goals

- No move or rewrite of the existing `docs/superpowers/` specs and plans — they remain the
  source of truth for design and are only *mined* for site content.
- No versioned docs (mike) — omac is single-channel and personal; one live version.
- No API/reference auto-generation tooling beyond reading the `# help:` command headers.
- No blog, changelog automation, or i18n.

## Tooling & deploy

| Concern | Choice | Notes |
|---|---|---|
| Generator | **Material for MkDocs** | Single `mkdocs.yml` at repo root. Markdown authoring. |
| Source dir | `docs/` (`docs_dir: docs`) | `exclude_docs: superpowers/` keeps internal specs unpublished. |
| Python deps | `docs-requirements.txt` | `mkdocs-material` (pulls in mkdocs). Pinned. |
| Local preview | `mkdocs serve` | Live reload at `127.0.0.1:8000`. |
| CI / deploy | `.github/workflows/docs.yml` | Build + publish to Pages on push to `main`. |
| Hosting | GitHub Pages | `afgallo.github.io/omac`; `CNAME`-ready for `omac.dev`. |

**Deploy mechanics.** The workflow uses the official GitHub Pages actions
(`actions/configure-pages`, `actions/upload-pages-artifact`, `actions/deploy-pages`) driving
`mkdocs build`, rather than pushing a `gh-pages` branch. This keeps the repo history clean and
uses the modern Pages-from-Actions source. The workflow needs `pages: write` and `id-token:
write` permissions and a `github-pages` environment. Pages must be set to "GitHub Actions" as
the build source (a one-time manual toggle in repo Settings → Pages; documented in the plan).

**`exclude_docs` interaction.** MkDocs treats every `.md` under `docs_dir` as a page. Because
`docs/superpowers/**` lives under `docs/`, it is excluded via the `exclude_docs` config key so
those files neither build nor emit "not in nav" warnings. `mkdocs build --strict` is used in CI
so broken links or stray-page warnings fail the build.

## Information architecture

Content lives under `docs/` (the publishable root). Proposed nav in `mkdocs.yml`:

```
Home                    docs/index.md
Getting Started         docs/getting-started/
  Requirements            requirements.md   (Apple Silicon, Sonoma 14 / Sequoia 15 / Tahoe 26)
  Install                 install.md        (curl … boot.sh | zsh, what it provisions)
  First run               first-run.md      (new terminal, omac doctor)
Commands                docs/commands/
  Overview                index.md          (dispatcher grammar: omac <cmd> [<sub>])
  install                 install.md
  software                software.md
  wm                      wm.md
  theme                   theme.md
  launcher                launcher.md
  update                  update.md
  doctor                  doctor.md
  uninstall               uninstall.md
  version / path          misc.md
Themes                  docs/themes/index.md   (10 bundled themes + swatches, set/list/current/reload,
                                                how a theme propagates across apps)
Software                docs/software/index.md (six groups: ai, shell, ides, tuis, guis, fonts;
                                                runtimes.manifest; opt-in/out model)
Window Management       docs/window-management/index.md (AeroSpace tiling, workspaces, SketchyBar,
                                                the hotkey map)
Architecture            docs/architecture/index.md (five modules, canonical paths, the dispatcher,
                                                migrations, the theme seam) — distilled from the
                                                master + module specs
Contributing            docs/contributing/index.md (repo layout, the zsh test suite test/run.zsh,
                                                adding a theme or command)
```

Command pages are written from each `cmd/*.zsh` file's `# help:` header and its usage `print`
block (the same text `omac help` and `omac <cmd>` emit), so the docs stay faithful to the CLI.

## README (repository landing page)

Replaces the current three-line `README.md`. Structure:

1. Title + one-line tagline: "Omarchy-style, keyboard-driven, fully-themed desktop for macOS."
2. Badge row: macOS Apple Silicon, shell (zsh), license (if/when added), docs-site link.
3. The install one-liner (`curl -fsSL … /boot.sh | zsh`) with a one-sentence "what it does."
4. A short "What you get" feature list (one-command theming, tiling + workspaces, declarative
   software groups, idempotent installer).
5. Two or three `omac` command examples (`omac theme set kanagawa`, `omac software install`,
   `omac doctor`).
6. A theme strip — the 10 bundled theme names (swatch images optional, added if cheap).
7. Prominent "→ Full documentation" link to the Pages site.
8. Short "Development" pointer (run tests with `test/run.zsh`; docs in `docs/`).

The README stays concise and authoritative; depth lives on the site. No content is duplicated
between the two beyond the install one-liner.

## Visual identity

- **Palette:** Material `slate` (dark) ⇄ `default` (light) with an automatic/OS-follow toggle,
  matching omac's own light/dark theming. A warm accent (amber/orange family) over near-black,
  evoking a terminal rice.
- **Type:** JetBrains Mono for code blocks (the font omac installs via `fonts.Brewfile`);
  system/Inter-style face for body.
- **Features enabled:** `navigation.instant`, `navigation.sections`, `navigation.top`,
  `search.suggest`, `content.code.copy`, `content.code.annotate`, `toc.follow`.
- **Admonitions:** used for the macOS-specific gotchas — Accessibility / Screen-Recording
  permission grants, the "open a new terminal after install" step, and Apple-Silicon-only /
  Sonoma-14-floor constraints.
- **Logo/favicon:** a simple `omac` monogram mark (SVG) if quick; otherwise a Material default
  icon. Not a blocker.

## The asciinema demo

The home page features a terminal cast of `omac theme set` switching a live desktop — the single
most compelling artifact, since the payoff is visual.

- **Embed:** the asciinema player (self-hosted `asciinema-player` CSS/JS assets committed under
  `docs/assets/`, referenced via `extra_css`/`extra_javascript`) playing a committed `.cast`
  file. Self-hosting avoids a runtime dependency on asciinema.org.
- **Recording is a real-machine step.** The cast must be captured on a Mac with the omac desktop
  actually installed (`asciinema rec`), which cannot happen in CI or this repo checkout. The plan
  therefore: (a) builds all embed infrastructure and page layout now, (b) documents the exact
  `asciinema rec` command and what to demo, (c) ships with a lightweight placeholder cast (or a
  static framed screenshot) until the real cast is dropped in at `docs/assets/omac-theme.cast`.
  Swapping in the real recording is then a single file replacement — no layout work.

## Testing & verification

- `mkdocs build --strict` passes locally and in CI (fails on broken links / stray pages).
- `mkdocs serve` renders every nav entry with no 404s; palette toggle and search work.
- The GitHub Action completes and Pages serves the site at the expected URL.
- The existing zsh test suite (`test/run.zsh`) is untouched and still green — this work adds no
  shell code, only docs, config, and CI.
- README renders correctly on GitHub (relative asset links resolve).

## Build order

1. Scaffold: `mkdocs.yml`, `docs-requirements.txt`, `docs/` tree with stub pages, `exclude_docs`.
2. CI: `.github/workflows/docs.yml` + document the one-time Pages "GitHub Actions" toggle.
3. Content: Home → Getting Started → Commands → Themes/Software/WM → Architecture → Contributing.
4. README rewrite.
5. asciinema embed infra + placeholder + recording instructions.
6. Visual polish (palette, fonts, logo) and `--strict` green.

Each step is independently verifiable with `mkdocs serve` / `mkdocs build --strict`.
