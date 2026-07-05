#!/usr/bin/env bash
# Clock: weekday, date, and 24h time. The calendar icon is static (set in
# sketchybarrc); this only refreshes the label.
sketchybar --set "$NAME" label="$(date '+%a %d %b  %H:%M')"
