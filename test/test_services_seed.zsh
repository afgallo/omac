#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

export OMAC_HOME="$ROOT"
source "$ROOT/lib/paths.zsh"

check "OMAC_SERVICES_SRC defaults under OMAC_HOME" "$ROOT/services" "$OMAC_SERVICES_SRC"

for f in docker-compose.yml .env; do
  present="$([[ -f "$ROOT/services/$f" ]] && print yes || print no)"
  check "$f exists" "yes" "$present"
done

compose="$(<"$ROOT/services/docker-compose.yml")"
contains "compose pins postgres alpine" "postgres:17-alpine" "$compose"
contains "compose pins redis alpine"    "redis:7-alpine"     "$compose"
contains "compose persists pgdata"      "pgdata"             "$compose"
contains "compose persists redisdata"   "redisdata"          "$compose"
contains "compose has a healthcheck"    "healthcheck"        "$compose"
contains "compose restarts unless-stopped" "unless-stopped"  "$compose"

env="$(<"$ROOT/services/.env")"
contains "env sets postgres db"   "POSTGRES_DB=omac" "$env"
contains "env sets postgres port" "POSTGRES_PORT=5432" "$env"
contains "env sets redis port"    "REDIS_PORT=6379"  "$env"

# Container tooling lives in its own software group.
containers="$(<"$ROOT/software/groups/containers.Brewfile")"
contains "containers has colima"         "colima"         "$containers"
contains "containers has docker"         'brew "docker"'  "$containers"
contains "containers has docker-compose" "docker-compose" "$containers"
finish
