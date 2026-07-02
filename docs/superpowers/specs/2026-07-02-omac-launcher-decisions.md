# omac `launcher` module — pre-spec decisions

**Status:** Superseded by `2026-07-02-omac-launcher-design.md` · **Date:** 2026-07-02 ·
**Parent:** `2026-06-18-omac-design.md` (module 4 of 6)

> **Superseded (2026-07-02):** the launcher brainstorm resumed and produced the approved design spec
> `2026-07-02-omac-launcher-design.md`. That spec **defers pillar 1 (omac Script Commands / "Omarchy
> Menu") to v1.1/v2** and builds v1 as pillar 2 only (guided Raycast activation). Read the design
> spec, not this doc, for the current plan; this file is kept for the decision history.

## Why this doc exists

We began brainstorming the `launcher` module, then decided to build **`theme` (module 5) first**
(see the build-order note in the master design). This captures the decisions already made so the
launcher brainstorm can resume cleanly — it is **not** an approved design spec. When we return to
`launcher`, restart the brainstorming flow from here, confirm the still-open items below, and only
then write the full `…-launcher-design.md` spec.

## Decisions made

### v1 scope (in)

1. **omac CLI Script Commands + "Omarchy Menu" surface** — Raycast Script Commands (plain
   executables with `@raycast.*` metadata comments) that call the `omac` CLI, plus an Omarchy-Menu
   style command surface for system actions. This is the launcher's reason to exist.
2. **Guided Raycast activation** — mirror `wm`'s guided first-run: help set Raycast as the
   Spotlight/launcher hotkey, register the omac script directory, enable clipboard history, grant
   permissions, and open the right prefs panes for the GUI-only steps.

### Out of v1 (deferred to v1.1)

- **Web-app quicklinks stay in `wm`.** The ChatGPT/Claude/Email/YouTube/X launches remain
  AeroSpace `open <url>` bindings for now; not relocated into Raycast quicklinks/deeplinks yet.
- **Snippets seeding deferred** — lowest-value / most personal.

### Command set: existing verbs only

Surface Raycast commands only for `omac` verbs that exist today: `update`, `wm reload`,
`wm status`, `doctor`, `software list`. The **`theme` module adds its own "Set Theme" launcher
command when it is built** (module 5 already owns Raycast as a palette-derived target). No
forward-reference from `launcher` to an unbuilt `theme`.

## Dependencies

**Build-order deps — all satisfied:**

- `bootstrap` ✓ — the `omac` CLI dispatcher and `omac::install_file` helper (Script Commands are
  `omac <verb>` calls).
- `software` ✓ — the `raycast` cask (`guis.Brewfile`).
- `wm` ✓ — the command set surfaces `omac wm reload` / `omac wm status`, so those verbs must exist.
  This is why `launcher` naturally sits after `wm`.
- **Not** dependent on `theme` (their Raycast surfaces are orthogonal: `theme` owns Raycast's
  *colors*, `launcher` owns its *Script Commands*).

**Runtime / behavioral gotchas to resolve in the launcher spec (verify against current Raycast):**

- **Script-execution PATH.** Raycast runs Script Commands in a minimal shell that does not source
  `.zprofile`/`.zshrc`, so `omac` (and `/opt/homebrew/bin`) may not be on PATH. Scripts must resolve
  the `omac` binary robustly (absolute path or explicit PATH export), not assume it's found.
- **Non-interactive / no TTY.** Raycast runs scripts without a TTY. `omac::confirm` reads
  `/dev/tty` and fail-safes to "no" when there's none — so a command like `omac update` (brew
  upgrade + migrations) would silently decline its own prompts unless we pass `OMAC_YES=1` or expose
  an output-only variant. This constrains which verbs are safe to surface and how.

## Still open (confirm when the brainstorm resumes)

- **How to realize the "Omarchy Menu."** Leaning toward *native Raycast searchable Script Commands*
  grouped under an `omac` package (Raycast's root fuzzy-search IS the menu) rather than a replicated
  hierarchical rofi-style tree or a full TypeScript/React extension — keeps everything plain-file and
  deployable via `omac::install_file`, mirroring `wm`. **Not yet approved.**
- Exact CLI surface (`omac launcher install` / `reload` / `status`?), layout under `launcher/` and
  `cmd/launcher/`, env override (`OMAC_LAUNCHER`), and the testing/stub approach — all follow the
  `wm` pattern but need to be specified.
- Whether the `theme` module, once built, should also *seed a Raycast theme* via the launcher's
  activation flow or entirely on its own.
