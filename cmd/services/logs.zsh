# help: tail the services container logs (passthrough to docker compose logs)
source "$OMAC_HOME/lib/services.zsh"
omac::services::logs "$@"
