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

if omac::confirm "Also delete $OMAC_CONFIG and $OMAC_STATE?"; then
  rm -rf "$OMAC_CONFIG" "$OMAC_STATE"
  omac::ok "removed config and state"
fi
omac::ok "uninstall complete"
