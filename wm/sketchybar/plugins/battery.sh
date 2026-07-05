#!/usr/bin/env bash
# Battery: charge-level glyph + percentage. Colors from the theme seam
# (colors.sh): plugged in → accent, low (<=20%) → red warning, else label color.
source "$HOME/.config/sketchybar/colors.sh"
# Glyph helper (omac::glyph). Guarded so unit tests that stub a bare HOME still
# run the percentage logic without it.
[ -r "$HOME/.config/sketchybar/plugins/icon_map.sh" ] && \
  source "$HOME/.config/sketchybar/plugins/icon_map.sh"
command -v omac::glyph >/dev/null 2>&1 || omac::glyph() { :; }

label="${LABEL_COLOR:-0xffcdd6f4}"
accent="${ACCENT_COLOR:-0xff89b4fa}"
warn="0xfff38ba8"   # theme-independent low-battery red

batt="$(pmset -g batt)"
pct="$(printf '%s\n' "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"
[ -z "$pct" ] && pct=0

# "Now drawing from 'AC Power'" when plugged in; anything else is on-battery.
if printf '%s\n' "$batt" | grep -q "'AC Power'"; then
  icon="$(omac::glyph f0e7)"   # bolt — charging
  color="$accent"
else
  # Battery glyph for the charge level (full → empty).
  if   [ "$pct" -ge 88 ]; then icon="$(omac::glyph f240)"   # full
  elif [ "$pct" -ge 63 ]; then icon="$(omac::glyph f241)"   # three-quarters
  elif [ "$pct" -ge 38 ]; then icon="$(omac::glyph f242)"   # half
  elif [ "$pct" -ge 13 ]; then icon="$(omac::glyph f243)"   # quarter
  else                         icon="$(omac::glyph f244)"   # empty
  fi
  if [ "$pct" -le 20 ]; then color="$warn"; else color="$label"; fi
fi

sketchybar --set "$NAME" icon="$icon" icon.color="$color" \
                 label="${pct}%" label.color="$color"
