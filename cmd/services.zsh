# help: manage the default dev services (postgres + redis via docker)
source "$OMAC_HOME/lib/services.zsh"
print -r -- "omac services — the default dev stack (postgres + redis on colima)"
print -r -- ""
print -r -- "Usage:"
print -r -- "  omac services up       deploy + start the stack; enable it at login"
print -r -- "  omac services down     stop the stack (data volumes are kept)"
print -r -- "  omac services status   show daemon + container status"
print -r -- "  omac services logs     tail container logs"
if [[ -n "${1:-}" ]]; then
  omac::warn "unknown subcommand: $1"
  return 1
fi
return 0
