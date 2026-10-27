#!/usr/bin/env bash
# Battery power draw in watts. Prints nothing (hiding the module) at 0 W, e.g. on
# the charger or on a machine without a battery.

POWER=$(cat /sys/class/power_supply/BAT*/power_now 2>/dev/null | head -1)
[ "${POWER:-0}" -gt 0 ] || exit 0
TEXT=$(awk -v p="$POWER" 'BEGIN { printf "%.1fW", p / 1000000 }')

jq -cn --arg text "$TEXT" '{$text, tooltip: "Power draw \($text)"}'
