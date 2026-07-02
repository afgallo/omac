#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

# Build an isolated OMAC_HOME with a nested command fixture.
fake="$(mktemp -d)"
ln -s "$ROOT/lib" "$fake/lib"
ln -s "$ROOT/bin" "$fake/bin"
mkdir -p "$fake/cmd/demo"
cat > "$fake/cmd/demo/run.zsh" <<'EOF'
# help: demo nested command
print -r -- "DEMO:$1"
EOF
cp "$ROOT/cmd/help.zsh" "$fake/cmd/help.zsh"

export OMAC_HOME="$fake"
export OMAC_CONFIG="$(mktemp -d)"

contains "nested command resolves and gets args" "DEMO:hello" "$(zsh "$fake/bin/omac" demo run hello)"
# falls back to flat when no nested match
contains "flat help still works" "Usage: omac" "$(zsh "$fake/bin/omac" help)"
finish
