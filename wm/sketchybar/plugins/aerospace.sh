#!/usr/bin/env bash
# omac — workspace item renderer. Draws one space pill: the workspace number
# plus a glyph for each app that has a window there. The focused workspace gets
# a filled accent pill; occupied-but-unfocused spaces show their apps in the
# label color; empty spaces dim out. $1 = this item's space id; FOCUSED is set
# by the aerospace_workspace_change trigger (see wm/aerospace/aerospace.toml).
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/plugins/icon_map.sh"

sid="$1"

# FOCUSED is provided by the aerospace_workspace_change trigger, but this same
# script is also subscribed to front_app_switched (to refresh app glyphs) — that
# event carries no FOCUSED, which would blank the highlight on every app switch.
# Fall back to asking AeroSpace directly so the focused pill always stays lit.
if [ -z "$FOCUSED" ] && command -v aerospace >/dev/null 2>&1; then
  FOCUSED="$(aerospace list-workspaces --focused 2>/dev/null)"
fi

# Derived tones from the three theme-seam colors: a dimmed label (~40% alpha)
# for empty spaces, and the bar color for text sitting on the accent pill.
label="${LABEL_COLOR:-0xffcdd6f4}"
accent="${ACCENT_COLOR:-0xff89b4fa}"
bar="${BAR_COLOR:-0xff1e1e2e}"
dim="0x66${label#0x??}"

# App glyphs for the windows on this workspace (deduped, capped at 4 so a busy
# space can't push the bar off-screen). Guard on aerospace being present.
apps=""
if command -v aerospace >/dev/null 2>&1; then
  seen=""
  while IFS= read -r app; do
    [ -z "$app" ] && continue
    case "$seen" in *"|$app|"*) continue ;; esac
    seen="$seen|$app|"
    apps="$apps$(omac::icon_for "$app") "
  done < <(aerospace list-windows --workspace "$sid" --format '%{app-name}' 2>/dev/null | head -4)
fi
apps="${apps% }"   # trim trailing space

if [ "$sid" = "$FOCUSED" ]; then
  # Focused: filled accent pill, dark-on-accent text.
  sketchybar --set "$NAME" label="$apps" \
             icon.color="$bar" label.color="$bar" \
             background.drawing=on background.color="$accent"
elif [ -n "$apps" ]; then
  # Occupied but not focused: number + apps in the label color, no fill.
  sketchybar --set "$NAME" label="$apps" \
             icon.color="$label" label.color="$label" \
             background.drawing=off
else
  # Empty: dim the number, hide the (absent) app strip.
  sketchybar --set "$NAME" label="" \
             icon.color="$dim" label.color="$dim" \
             background.drawing=off
fi
