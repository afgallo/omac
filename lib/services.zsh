# The services engine: run the default dev stack (Postgres + Redis) on a Colima
# Docker daemon. Sourced by cmd/services/*. Colima gives a lightweight Linux VM
# providing the Docker daemon — no Docker Desktop, CLI-only. The stack itself is
# a docker-compose.yml deployed (non-destructively) to $OMAC_SERVICES_CONFIG so
# the user can tune credentials/ports without losing them on the next omac run.
#
# Colima VM sizing is overridable for tests/tuning; the defaults are a modest dev
# box (2 CPU / 4 GB RAM / 20 GB disk).
: ${OMAC_COLIMA_CPU:=2}
: ${OMAC_COLIMA_MEMORY:=4}
: ${OMAC_COLIMA_DISK:=20}

# Deploy the compose stack + its .env into the user config dir. Idempotent and
# non-destructive: install_file skips identical files and backs up differing ones
# (returning non-zero when the user declines — so we must stop, not skip).
omac::services::deploy() {
  mkdir -p "$OMAC_SERVICES_CONFIG"
  omac::install_file "$OMAC_SERVICES_SRC/docker-compose.yml" "$OMAC_SERVICES_CONFIG/docker-compose.yml" || return 1
  omac::install_file "$OMAC_SERVICES_SRC/.env"               "$OMAC_SERVICES_CONFIG/.env"               || return 1
}

# Resolve the compose command words. Prefer the `docker compose` plugin (Docker
# Desktop), fall back to the standalone `docker-compose` binary — brew's `docker`
# formula ships no compose plugin, so on a colima box only the standalone binary
# (from the containers Brewfile) exists. Prints the command; non-zero if neither.
omac::services::compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    print -r -- "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    print -r -- "docker-compose"
  else
    return 1
  fi
}

# Run compose against the deployed stack. Runs from the config dir in a subshell
# so compose treats it as the project directory and auto-loads the sibling .env.
# Fails clearly if the stack was never deployed or no compose command exists.
omac::services::compose() {   # <compose-args...>
  omac::require_cmd docker || return 1
  local dir="$OMAC_SERVICES_CONFIG"
  if [[ ! -f "$dir/docker-compose.yml" ]]; then
    omac::error "no stack deployed at $dir/docker-compose.yml — run: omac services up"
    return 1
  fi
  local -a cc
  if ! cc=(${=$(omac::services::compose_cmd)}); then
    omac::error "no compose found — run: omac software install containers"
    return 1
  fi
  ( cd "$dir" && "${cc[@]}" -f docker-compose.yml "$@" )
}

# Ensure the Colima Docker daemon is running (start it with our defaults if not).
omac::services::daemon_up() {
  omac::require_cmd colima || return 1
  if colima status >/dev/null 2>&1; then
    omac::info "colima already running"
    return 0
  fi
  omac::info "starting colima (${OMAC_COLIMA_CPU} CPU / ${OMAC_COLIMA_MEMORY} GB)"
  colima start --cpu "$OMAC_COLIMA_CPU" --memory "$OMAC_COLIMA_MEMORY" --disk "$OMAC_COLIMA_DISK"
}

# Bring the stack online from already-deployed config: start the daemon, then the
# containers. No deploy, no agent install — safe to run headless (this is what the
# login LaunchAgent calls).
omac::services::boot() {
  omac::services::daemon_up || return 1
  omac::info "starting default stack (postgres + redis)"
  omac::services::compose up -d
}

# Write and load a per-user LaunchAgent that boots the stack at login, so the
# containers are up out of the box after a reboot. Mirrors the wm module's agent
# pattern. Idempotent: the plist is rewritten and re-bootstrapped every call.
# The agent runs `omac services boot` with an explicit PATH (login agents get a
# bare PATH that lacks the brew prefix where colima/docker live).
omac::services::install_agent() {
  local label="com.omac.services"
  local agents="${OMAC_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}"
  local plist="$agents/$label.plist"
  local prefix; prefix="$(omac::prefix)"
  mkdir -p "$agents"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$prefix/bin/omac</string>
    <string>services</string>
    <string>boot</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$prefix/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST
  command -v launchctl >/dev/null 2>&1 || return 0
  # Re-bootstrap so an existing agent picks up changes. bootout is a no-op (and
  # errors) when nothing is loaded yet, so swallow its failure.
  local domain="gui/$(id -u)"
  launchctl bootout "$domain/$label" 2>/dev/null
  launchctl bootstrap "$domain" "$plist" 2>/dev/null
  omac::info "installed services LaunchAgent ($plist)"
}

# First-run entrypoint: deploy the stack, bring it up, and wire the login agent
# so it stays up out of the box. Safe to re-run.
omac::services::up() {
  omac::require_cmd docker || return 1
  omac::services::deploy    || return 1
  omac::services::boot      || return 1
  omac::services::install_agent
  omac::ok "services up — postgres + redis running; login agent keeps them up"
}

# Stop the stack (keeps named volumes, so data survives).
omac::services::down() {
  omac::services::compose down
}

# Non-mutating status: is the daemon up, and what are the containers doing?
omac::services::status() {
  if command -v colima >/dev/null 2>&1 && colima status >/dev/null 2>&1; then
    omac::ok "colima daemon running"
  else
    omac::warn "colima daemon not running (run: omac services up)"
  fi
  omac::services::compose ps
}

# Tail/inspect container logs (passthrough to `docker compose logs`).
omac::services::logs() {   # <compose-logs-args...>
  omac::services::compose logs "$@"
}
