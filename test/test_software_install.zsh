#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"
source "$ROOT/test/software_stubs.zsh"
source "$ROOT/lib/common.zsh"

export OMAC_SOFTWARE="$(mktemp -d)/software"
mkdir -p "$OMAC_SOFTWARE/groups"
print -r -- 'brew "ripgrep"' > "$OMAC_SOFTWARE/groups/shell.Brewfile"
cat > "$OMAC_SOFTWARE/runtimes.manifest" <<'EOF'
# comment line
node@lts
python@3.13
EOF

_stub_setup
source "$ROOT/lib/software.zsh"

# Satisfied group (check passes): fast path skips the full bundle.
: > "$BREW_LOG"
BREW_CHECK_RC=0 omac::software::install_group shell >/dev/null 2>&1
check "install_group satisfied exits 0" "0" "$?"
contains "check probe ran" "bundle check --file=$OMAC_SOFTWARE/groups/shell.Brewfile" "$(<"$BREW_LOG")"
if [[ "$(<"$BREW_LOG")" == *"bundle --file=$OMAC_SOFTWARE/groups/shell.Brewfile"* ]]; then
  check "satisfied group skips brew bundle" "skipped" "ran"
else
  check "satisfied group skips brew bundle" "skipped" "skipped"
fi

# Missing group (check fails): fall through to the real bundle.
: > "$BREW_LOG"
BREW_CHECK_RC=1 omac::software::install_group shell >/dev/null 2>&1
check "install_group missing exits 0" "0" "$?"
contains "brew bundle ran on shell Brewfile" "bundle --file=$OMAC_SOFTWARE/groups/shell.Brewfile" "$(<"$BREW_LOG")"

omac::software::install_group nope >/dev/null 2>&1
check "install_group unknown exits 1" "1" "$?"

omac::software::install_runtimes >/dev/null 2>&1
check "install_runtimes exits 0" "0" "$?"
mise_out="$(<"$MISE_LOG")"
contains "mise use -g invoked" "use -g" "$mise_out"
contains "mise got node@lts"   "node@lts" "$mise_out"
contains "mise got python"     "python@3.13" "$mise_out"
contains "mise skipped comment" "use -g node@lts python@3.13" "$mise_out"
contains "ruby set to precompiled" "settings set ruby.compile false" "$mise_out"
finish
