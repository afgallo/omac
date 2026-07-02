#!/usr/bin/env bash
# Highlight the focused workspace. $1 = this item's space id; FOCUSED is set by
# the aerospace_workspace_change trigger.
source "$HOME/.config/sketchybar/colors.sh"
if [ "$1" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" label.color="$ACCENT_COLOR"
else
  sketchybar --set "$NAME" label.color="$LABEL_COLOR"
fi
