#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/services_stubs.zsh"

# Minimal fake OMAC_HOME (symlinked lib/bin/cmd) so the dispatcher runs.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
ln -s "$ROOT/cmd" "$fake/cmd"
export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_SERVICES_SRC="$ROOT/services"                # real stack fixtures
export OMAC_SERVICES_CONFIG="$OMAC_CONFIG/services"

_services_stub_setup

# bare usage
bare="$(zsh "$fake/bin/omac" services)"
contains "bare prints usage"    "Usage" "$bare"
contains "bare lists up"         "up"   "$bare"
contains "bare lists status"     "status" "$bare"

# unknown subcommand → nonzero
zsh "$fake/bin/omac" services bogus >/dev/null 2>&1
check "unknown subcommand exits 1" "1" "$?"

# up: deploy stack, start colima, compose up -d, install login agent
zsh "$fake/bin/omac" services up >/dev/null 2>&1
check "up exits 0" "0" "$?"
present="$([[ -f "$OMAC_SERVICES_CONFIG/docker-compose.yml" ]] && print yes || print no)"
check "up deployed compose file"  "yes" "$present"
present="$([[ -f "$OMAC_SERVICES_CONFIG/.env" ]] && print yes || print no)"
check "up deployed .env"          "yes" "$present"
contains "up started colima"      "start"             "$(<"$COLIMA_LOG")"
contains "up ran compose up -d"   "up -d"             "$(<"$DOCKER_LOG")"
contains "up bootstrapped agent"  "com.omac.services" "$(<"$LAUNCHCTL_LOG")"
present="$([[ -f "$OMAC_LAUNCHAGENTS/com.omac.services.plist" ]] && print yes || print no)"
check "up wrote the plist"        "yes" "$present"

# re-run up is idempotent (identical files → no prompt, still exits 0)
zsh "$fake/bin/omac" services up >/dev/null 2>&1
check "up re-run exits 0" "0" "$?"

# down
: > "$DOCKER_LOG"
zsh "$fake/bin/omac" services down >/dev/null 2>&1
check "down exits 0" "0" "$?"
contains "down ran compose down" "down" "$(<"$DOCKER_LOG")"

# status runs compose ps
: > "$DOCKER_LOG"
zsh "$fake/bin/omac" services status >/dev/null 2>&1
contains "status ran compose ps" "ps" "$(<"$DOCKER_LOG")"

# boot (login-agent entry): start daemon + compose up, no deploy/agent needed
: > "$COLIMA_LOG"; : > "$DOCKER_LOG"; : > "$LAUNCHCTL_LOG"
zsh "$fake/bin/omac" services boot >/dev/null 2>&1
check "boot exits 0" "0" "$?"
contains "boot started colima"    "start" "$(<"$COLIMA_LOG")"
contains "boot ran compose up -d" "up -d" "$(<"$DOCKER_LOG")"
check "boot did not touch launchctl" "" "$(<"$LAUNCHCTL_LOG")"
finish
