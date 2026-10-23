#!/usr/bin/env bash
# Battery power draw in watts. Prints nothing (hiding the module) at 0 W, e.g. on
# the charger or on a machine without a battery.

POWER=$(cat /sys/class/power_supply/BAT*/power_now 2>/dev/null | head -1)
WATTS=$(( ${POWER:-0} / 1000000 ))
[ "$WATTS" -gt 0 ] || exit 0

jq -cn --arg text "${WATTS}W" '{$text, tooltip: "Power draw \($text)"}'
