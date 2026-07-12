# Shared test stubs: fake `colima`, `docker`, and `launchctl` on PATH that log
# their args to files. Call _services_stub_setup AFTER exporting OMAC_* env.
# Exposes $COLIMA_LOG, $DOCKER_LOG, $LAUNCHCTL_LOG and points OMAC_LAUNCHAGENTS at
# a temp dir so tests never touch the real ~/Library/LaunchAgents.
_services_stub_setup() {
  local dir; dir="$(mktemp -d)"
  export COLIMA_LOG="$(mktemp)" DOCKER_LOG="$(mktemp)" LAUNCHCTL_LOG="$(mktemp)"
  export OMAC_LAUNCHAGENTS="$dir/LaunchAgents"
  cat > "$dir/colima" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$COLIMA_LOG"
# `colima status` returns COLIMA_RUNNING (default 1 = not running) so daemon_up
# decides whether to start it.
[[ "$1" == "status" ]] && exit "${COLIMA_RUNNING:-1}"
exit 0
SH
  # docker CLI stand-in with NO bundled compose plugin (like brew's docker
  # formula): `docker compose …` fails, so the engine falls back to the
  # standalone docker-compose binary below.
  cat > "$dir/docker" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$DOCKER_LOG"
[[ "$1" == "compose" ]] && exit 1
exit 0
SH
  # Standalone docker-compose (installed by the containers Brewfile). Logs to the
  # same file so the CLI tests can assert on compose subcommands.
  cat > "$dir/docker-compose" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$DOCKER_LOG"
exit 0
SH
  cat > "$dir/launchctl" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$LAUNCHCTL_LOG"
exit 0
SH
  chmod +x "$dir/colima" "$dir/docker" "$dir/docker-compose" "$dir/launchctl"
  export PATH="$dir:$PATH"
}
