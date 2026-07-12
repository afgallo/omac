# help: deploy and start the default stack (postgres + redis), enabling it at login
source "$OMAC_HOME/lib/services.zsh"
omac::services::up
