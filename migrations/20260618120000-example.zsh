#!/usr/bin/env zsh
# Example migration: a no-op that demonstrates the pattern.
# RULE: migrations must be idempotent — they may partially run then rerun.
#   WRONG: echo 'x' >> ~/.zprofile        (doubles on rerun)
#   RIGHT: grep -qF 'x' ~/.zprofile || echo 'x' >> ~/.zprofile
exit 0
