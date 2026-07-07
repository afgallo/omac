# help: remove the omac CLI symlink, shell integration, and (optionally) config
typeset prefix bindir
prefix="$(omac::prefix)"
bindir="$prefix/bin"

if [[ -L "$bindir/omac" ]]; then
  rm -f "$bindir/omac"
  omac::ok "removed CLI symlink"
fi

omac::remove_block "$OMAC_PROFILE"
omac::ok "removed shell integration from $OMAC_PROFILE"

# Remove the interactive-shell blocks the `shell` module wrote (no-op if absent).
typeset rc
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [[ -f "$rc" ]] && grep -qF '>>> omac >>>' "$rc" 2>/dev/null; then
    omac::remove_block "$rc"
    omac::ok "removed shell config from ${rc:t}"
  fi
done

# Reverse the one system change launcher makes (re-enable Spotlight ⌘Space).
# No-op if it was never freed; best-effort so a broken env can't block uninstall.
source "$OMAC_HOME/lib/launcher.zsh"
omac::launcher::restore_spotlight_hotkey || omac::warn "could not restore ⌘Space"

if omac::confirm "Also delete $OMAC_CONFIG and $OMAC_STATE?"; then
  rm -rf "$OMAC_CONFIG" "$OMAC_STATE"
  omac::ok "removed config and state"
fi
omac::ok "uninstall complete"
