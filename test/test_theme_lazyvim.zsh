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
export OMAC_NVIM="$ROOT/nvim"   # omac-owned dx/extras specs live in the repo
mkdir -p "$OMAC_CURRENT"
print -r -- 'return {}' > "$OMAC_CURRENT/neovim.lua"

_theme_stub_setup   # provides a logging `git` stub (GIT_LOG) among others

# Upgrade the git stub so `clone` actually materialises a fake starter (with a
# .git dir we expect bootstrap to remove), mirroring the real command — down to
# the lua/config/lazy.lua spec block wire_lazy_extras anchors on.
STUB_BIN="${PATH%%:*}"
cat > "$STUB_BIN/git" <<'SH'
#!/usr/bin/env zsh
print -r -- "$*" >> "$GIT_LOG"
if [[ "$1" == "clone" ]]; then
  dest="${@[-1]}"
  mkdir -p "$dest/.git" "$dest/lua/config"
  print -r -- "starter" > "$dest/init.lua"
  cat > "$dest/lua/config/lazy.lua" <<'LUA'
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
})
LUA
fi
exit 0
SH
chmod +x "$STUB_BIN/git"

source "$ROOT/lib/theme.zsh"

# 1. Fresh machine: wire scaffolds LazyVim, then links the omac specs.
omac::theme::wire >/dev/null 2>&1
contains "cloned the LazyVim starter" "clone --depth 1 https://github.com/LazyVim/starter" "$(<"$GIT_LOG")"
check "starter init.lua created" "1" "$([[ -f "$XDG_CONFIG_HOME/nvim/init.lua" ]] && print 1 || print 0)"
check ".git removed after clone" "1" "$([[ ! -e "$XDG_CONFIG_HOME/nvim/.git" ]] && print 1 || print 0)"
check "theme plugin linked into starter" "1" \
  "$([[ -L "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-theme.lua" ]] && print 1 || print 0)"
check "dx plugin linked into starter" "1" \
  "$([[ -L "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-dx.lua" ]] && print 1 || print 0)"
check "dx plugin points at omac install" "$ROOT/nvim/omac-dx.lua" \
  "$(readlink "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-dx.lua")"
check "extras module points at omac install" "$ROOT/nvim/omac-extras.lua" \
  "$(readlink "$XDG_CONFIG_HOME/nvim/lua/omac/extras.lua")"

# 2. Extras import spliced into config/lazy.lua BEFORE the user plugins import
# (LazyVim's required order), and the pre-patch file is backed up.
LAZY="$XDG_CONFIG_HOME/nvim/lua/config/lazy.lua"
contains "omac.extras imported in lazy.lua" '{ import = "omac.extras" },' "$(<"$LAZY")"
extras_line="$(grep -nF 'omac.extras' "$LAZY" | head -1)"
plugins_line="$(grep -nF '{ import = "plugins" }' "$LAZY" | head -1)"
check "extras import precedes plugins import" "1" \
  "$(( ${extras_line%%:*} < ${plugins_line%%:*} ? 1 : 0 ))"
check "lazy.lua backed up before patch" "1" \
  "$(ls "$LAZY".omac-backup.* >/dev/null 2>&1 && print 1 || print 0)"

# 3. Idempotent: an existing nvim config is left untouched (no second clone),
# the extras import isn't duplicated, and no fresh backup is taken.
: > "$GIT_LOG"
omac::theme::wire >/dev/null 2>&1
check "no clone when nvim config exists" "" "$(<"$GIT_LOG")"
check "user init.lua preserved" "starter" "$(<"$XDG_CONFIG_HOME/nvim/init.lua")"
check "extras import not duplicated" "1" "$(grep -cF 'omac.extras' "$LAZY")"
check "no second backup on re-run" "1" "$(ls "$LAZY".omac-backup.* | wc -l | tr -d ' ')"

# 4. Migration: a pre-extras omac-lang.lua symlink in lua/plugins/ is removed
# (its extras imports tripped LazyVim's import-order check).
ln -sfn "$ROOT/nvim/omac-extras.lua" "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-lang.lua"
omac::theme::wire >/dev/null 2>&1
check "stale omac-lang.lua symlink removed" "1" \
  "$([[ ! -e "$XDG_CONFIG_HOME/nvim/lua/plugins/omac-lang.lua" ]] && print 1 || print 0)"

finish
