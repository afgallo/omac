#!/usr/bin/env bash
# Network: a single status glyph — Wi-Fi, wired, or offline — sitting just left
# of the battery. Colors from the theme seam (colors.sh): connected → accent,
# offline → dimmed label. Refreshed on a short poll, on wifi_change, and on wake.
source "$HOME/.config/sketchybar/colors.sh"
# Glyph helper (omac::glyph). Guarded so unit tests that stub a bare HOME still
# exercise the detection logic without it.
[ -r "$HOME/.config/sketchybar/plugins/icon_map.sh" ] && \
  source "$HOME/.config/sketchybar/plugins/icon_map.sh"
command -v omac::glyph >/dev/null 2>&1 || omac::glyph() { :; }

label="${LABEL_COLOR:-0xffcdd6f4}"
accent="${ACCENT_COLOR:-0xff89b4fa}"
dim="0x66${label#0x??}"   # ~40% alpha label tone for the offline state

# Interface carrying the default route (empty when there's no upstream at all).
iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"

# The Wi-Fi hardware device (usually en0) — lets us tell Wi-Fi from Ethernet.
# In `networksetup -listallhardwareports` the device line follows its port line.
wifi_dev="$(networksetup -listallhardwareports 2>/dev/null \
  | awk '/Wi-Fi|AirPort/{getline; print $2; exit}')"

if [ -z "$iface" ] || ! ifconfig "$iface" 2>/dev/null | grep -q 'status: active'; then
  icon="$(omac::glyph f127)"   # broken link — offline
  color="$dim"
elif [ "$iface" = "$wifi_dev" ]; then
  icon="$(omac::glyph f1eb)"   # wifi
  color="$accent"
else
  icon="$(omac::glyph f6ff)"   # network-wired
  color="$accent"
fi

sketchybar --set "$NAME" icon="$icon" icon.color="$color" label=""
