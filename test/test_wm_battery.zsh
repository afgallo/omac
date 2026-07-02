#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

# Structure: the real plugin exists, is executable, and is registered.
check "battery.sh exists"     "yes" "$([[ -f "$ROOT/wm/sketchybar/plugins/battery.sh" ]] && print yes || print no)"
check "battery.sh executable" "yes" "$([[ -x "$ROOT/wm/sketchybar/plugins/battery.sh" ]] && print yes || print no)"
check "sketchybarrc registers battery" "yes" "$(grep -q 'item battery' "$ROOT/wm/sketchybar/sketchybarrc" && print yes || print no)"

# Logic: stub pmset + sketchybar, provide a colors.sh, run the plugin.
stub="$(mktemp -d)"
export SKETCHYBAR_LOG="$(mktemp)"
cat > "$stub/pmset" <<'SH'
#!/usr/bin/env bash
printf "%s\n" "Now drawing from 'Battery Power'"
printf " -InternalBattery-0 (id=1)\t83%%; discharging; 4:32 remaining present: true\n"
SH
cat > "$stub/sketchybar" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$SKETCHYBAR_LOG"
SH
chmod +x "$stub/pmset" "$stub/sketchybar"

export HOME="$(mktemp -d)"
mkdir -p "$HOME/.config/sketchybar"
print -r -- 'export LABEL_COLOR=0xffcdd6f4' > "$HOME/.config/sketchybar/colors.sh"

PATH="$stub:$PATH" NAME=battery bash "$ROOT/wm/sketchybar/plugins/battery.sh"
contains "battery label shows percent" "label=83%" "$(<"$SKETCHYBAR_LOG")"
finish
