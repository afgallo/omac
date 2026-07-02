# help: print resolved omac directories
print -r -- "OMAC_HOME=$OMAC_HOME"
print -r -- "OMAC_CONFIG=$OMAC_CONFIG"
print -r -- "OMAC_STATE=$OMAC_STATE"
print -r -- "themes=$OMAC_THEMES"
print -r -- "templates=$OMAC_TEMPLATES"
print -r -- "current=$OMAC_CURRENT"
print -r -- "profile=$OMAC_PROFILE"
print -r -- "prefix=$(omac::prefix)"
