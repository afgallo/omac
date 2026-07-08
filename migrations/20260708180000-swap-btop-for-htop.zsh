#!/usr/bin/env zsh
# btop is out of the tuis group (replaced by htop, which needs no theme seam).
# Uninstall btop, drop the omac-managed color_theme block from its config, and
# make sure htop is present. Idempotent: every step checks before acting.
emulate -L zsh

source "$OMAC_HOME/lib/common.zsh"

# Drop the color_theme omac wrote into btop's config; leave the rest of the
# file (user settings) alone. Two shapes: the managed block as omac wrote it,
# or a bare line — btop rewrites its config on exit, flattening the markers.
conf="${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"
omac::remove_block "$conf"
if [[ -f "$conf" ]] && grep -q 'omac/current/btop\.theme' "$conf"; then
  tmp="$conf.omac.tmp"
  sed 's|^color_theme = ".*omac/current/btop\.theme"$|color_theme = "Default"|' "$conf" > "$tmp" \
    && mv "$tmp" "$conf"
  omac::info "reset btop color_theme to Default"
fi

if command -v brew >/dev/null 2>&1; then
  if brew list --formula btop >/dev/null 2>&1; then
    omac::info "uninstalling btop"
    brew uninstall btop
  fi
  if ! brew list --formula htop >/dev/null 2>&1; then
    omac::info "installing htop"
    brew install --quiet htop
  fi
fi
exit 0
