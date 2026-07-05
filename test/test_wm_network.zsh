#!/usr/bin/env zsh
emulate -L zsh
ROOT="${0:A:h:h}"
source "$ROOT/test/helper.zsh"

# Structure: the real plugin exists, is executable, and is registered left of
# the battery (added after it, since right items stack corner-inward).
check "network.sh exists"     "yes" "$([[ -f "$ROOT/wm/sketchybar/plugins/network.sh" ]] && print yes || print no)"
check "network.sh executable" "yes" "$([[ -x "$ROOT/wm/sketchybar/plugins/network.sh" ]] && print yes || print no)"
check "sketchybarrc registers network" "yes" "$(grep -q 'item network' "$ROOT/wm/sketchybar/sketchybarrc" && print yes || print no)"
rc="$ROOT/wm/sketchybar/sketchybarrc"
batt_line="$(grep -nE 'item battery right' "$rc" | head -1 | cut -d: -f1)"
net_line="$(grep -nE 'item network right' "$rc" | head -1 | cut -d: -f1)"
check "network added after battery (sits to its left)" "yes" \
  "$([[ -n "$batt_line" && -n "$net_line" && "$net_line" -gt "$batt_line" ]] && print yes || print no)"

# Shared harness: stub sketchybar + net tooling, provide a colors.sh.
setup() {
  stub="$(mktemp -d)"
  export SKETCHYBAR_LOG="$(mktemp)"
  cat > "$stub/sketchybar" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$SKETCHYBAR_LOG"
SH
  cat > "$stub/networksetup" <<'SH'
#!/usr/bin/env bash
# Minimal -listallhardwareports: Wi-Fi maps to device en0.
printf "Hardware Port: Wi-Fi\nDevice: en0\nEthernet Address: 00:00:00:00:00:00\n"
SH
  chmod +x "$stub/sketchybar" "$stub/networksetup"
  export HOME="$(mktemp -d)"
  mkdir -p "$HOME/.config/sketchybar"
  print -r -- 'export LABEL_COLOR=0xffcdd6f4' >  "$HOME/.config/sketchybar/colors.sh"
  print -r -- 'export ACCENT_COLOR=0xff89b4fa' >> "$HOME/.config/sketchybar/colors.sh"
}

# Offline: no default route → dimmed offline glyph (not accent).
setup
cat > "$stub/route" <<'SH'
#!/usr/bin/env bash
exit 1
SH
cat > "$stub/ifconfig" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$stub/route" "$stub/ifconfig"
PATH="$stub:$PATH" NAME=network bash "$ROOT/wm/sketchybar/plugins/network.sh"
contains "offline uses dimmed color" "icon.color=0x66cdd6f4" "$(<"$SKETCHYBAR_LOG")"

# Wi-Fi: default route on en0, interface active → accent color.
setup
cat > "$stub/route" <<'SH'
#!/usr/bin/env bash
printf "   interface: en0\n"
SH
cat > "$stub/ifconfig" <<'SH'
#!/usr/bin/env bash
printf "\tstatus: active\n"
SH
chmod +x "$stub/route" "$stub/ifconfig"
PATH="$stub:$PATH" NAME=network bash "$ROOT/wm/sketchybar/plugins/network.sh"
contains "connected uses accent color" "icon.color=0xff89b4fa" "$(<"$SKETCHYBAR_LOG")"
finish
