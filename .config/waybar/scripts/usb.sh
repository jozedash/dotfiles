#!/usr/bin/env bash
# Drives udiskie has mounted under /run/media/$USER. Prints nothing (hiding the
# module) when there are none. udiskie's event_hook refreshes it (signal 10).

MOUNTS=$(findmnt -J -o TARGET,SOURCE,SIZE,FSTYPE | jq -c --arg dir "/run/media/$USER/" \
    '[.. | objects | select(.target? // "" | startswith($dir))]')
COUNT=$(jq length <<< "$MOUNTS")
[ "$COUNT" -gt 0 ] || exit 0

TOOLTIP=$(jq -r '.[] | "\(.target | split("/") | last)  \(.size) \(.fstype)  (\(.source))"' <<< "$MOUNTS")
TOOLTIP+=$'\n\nClick to browse, right-click to unmount all'
CLASS=mounted
[ "$COUNT" -gt 1 ] && TEXT=$COUNT || { TEXT=" "; CLASS+=" icon-only"; }

jq -cn --arg text "$TEXT" --arg tooltip "$TOOLTIP" --arg class "$CLASS" '{$text, $tooltip, class: ($class / " ")}'
