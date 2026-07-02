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
