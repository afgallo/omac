# Run any migration whose marker is absent, in filename order, then mark it.
# A migration is marked ONLY after exit 0. On failure the user may skip it — the
# skip is recorded in a SEPARATE ledger so it neither reruns nor blocks the rest;
# declining aborts. (Skip-tracking mined from omarchy's omarchy-migrate.) Every
# migration MUST still be internally idempotent (check-then-act).
omac::migrate() {
  setopt local_options null_glob
  mkdir -p "$OMAC_MIGRATIONS_STATE" "$OMAC_MIGRATIONS_STATE/skipped"
  local f id
  for f in "$OMAC_HOME"/migrations/*.zsh; do
    id="${f:t:r}"
    [[ -e "$OMAC_MIGRATIONS_STATE/$id" || -e "$OMAC_MIGRATIONS_STATE/skipped/$id" ]] && continue
    omac::info "running migration $id"
    if zsh "$f"; then
      : > "$OMAC_MIGRATIONS_STATE/$id"
    elif omac::confirm "migration $id failed — skip and continue?"; then
      : > "$OMAC_MIGRATIONS_STATE/skipped/$id"
      omac::warn "skipped migration $id"
    else
      omac::error "migration failed: $id"
      return 1
    fi
  done
  return 0
}
