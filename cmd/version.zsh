# help: print the omac version
local v="unknown"
[[ -f "$OMAC_HOME/version" ]] && v="$(<"$OMAC_HOME/version")"
local sha=""
if command -v git >/dev/null 2>&1 && git -C "$OMAC_HOME" rev-parse --short HEAD >/dev/null 2>&1; then
  sha=" ($(git -C "$OMAC_HOME" rev-parse --short HEAD))"
fi
print -r -- "omac $v$sha"
