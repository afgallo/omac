# help: stop the default stack (postgres + redis); data volumes are kept
source "$OMAC_HOME/lib/services.zsh"
omac::services::down
