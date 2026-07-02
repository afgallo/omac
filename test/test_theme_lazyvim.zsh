#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/theme_stubs.zsh"
source "$ROOT/lib/common.zsh"

# Isolated deploy root; config_dir() reads XDG_CONFIG_HOME.
export XDG_CONFIG_HOME="$(mktemp -d)"
export HOME="$(mktemp -d)"
export OMAC_CONFIG="$(mktemp -d)"
export OMAC_CURRENT="$OMAC_CONFIG/current"
mkdir -p "$OMAC_CURRENT"
print -r -- 'return {}' > "$OMAC_CURRENT/neovim.lua"

_theme_stub_setup   # provides a logging `git` stub (GIT_LOG) among others

# Upgrade the git stub so `clone` actually materialises a fake starter (with a
# .git dir we expect bootstrap to remove), mirroring the real command.
STUB_BIN="${PATH%%:*}"
cat > "$STUB_BIN/git" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$GIT_LOG"
if [[ "$1" == "clone" ]]; then
  dest="${@[-1]}"
  mkdir -p "$dest/.git"
  print -r -- "starter" > "$dest/init.lua"
fi
exit 0
SH
chmod +x "$STUB_BIN/git"

source "$ROOT/lib/theme.zsh"

# 1. Fresh machine: wire scaffolds LazyVim, then links the theme plugin.
omac::theme::wire >/dev/null 2>&1
contains "cloned the LazyVim starter" "clone --depth 1 https://github.com/LazyVim/starter" "$(<"$GIT_LOG")"
check "starter init.lua created" "1" "$([[ -f "$XDG_CONFIG_HOME/nvim/init.lua" ]] && print 1 || print 0)"
check ".git removed after clone" "1" "$([[ ! -e "$XDG_CONFIG_HOME/nvim/.git" ]] && print 1 || print 0)"
check "theme plugin linked into starter" "1" \
  "$([[ -L "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-theme.lua" ]] && print 1 || print 0)"

# 2. Idempotent: an existing nvim config is left untouched (no second clone).
: > "$GIT_LOG"
omac::theme::wire >/dev/null 2>&1
check "no clone when nvim config exists" "" "$(<"$GIT_LOG")"
check "user init.lua preserved" "starter" "$(<"$XDG_CONFIG_HOME/nvim/init.lua")"

finish
