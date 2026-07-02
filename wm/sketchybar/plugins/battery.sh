#!/usr/bin/env bash
# Battery: percentage + charge state. Colors from the theme seam (colors.sh).
source "$HOME/.config/sketchybar/colors.sh"

batt="$(pmset -g batt)"
pct="$(printf '%s\n' "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
[ -z "$pct" ] && pct=0

# "Now drawing from 'AC Power'" when plugged in; anything else is on-battery.
if printf '%s\n' "$batt" | grep -q "'AC Power'"; then
  icon=""   # nf-md-power_plug — charging
else
  icon=""   # nf-md-battery — on battery
fi

sketchybar --set "$NAME" icon="$icon" label="${pct}%" label.color="$LABEL_COLOR"
