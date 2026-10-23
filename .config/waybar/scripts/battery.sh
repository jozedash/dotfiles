#!/usr/bin/env bash
#
# Usage: battery.sh [toggle]
#   No argument: print waybar JSON for the battery (nothing if there's no battery)
#   toggle:      switch Long Life (conservation) mode on or off
#
# Long Life makes the firmware hold the charge at about 60%. Writing charge_types
# needs the udev rule in hosts/<model>/etc/udev/rules.d/.

HOST_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles-host/host.sh"
[ -f "$HOST_CONF" ] && . "$HOST_CONF"

if [ -z "$BATTERY" ]; then
    BATTERY=$(basename "$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)")
fi
DIR="/sys/class/power_supply/$BATTERY"
[ -n "$BATTERY" ] && [ -d "$DIR" ] || exit 0

# charge_types looks like "[Standard] Long_Life"; the bracketed one is active
MODE=$(grep -oP '\[\K[^]]+' "$DIR/charge_types" 2>/dev/null)

if [ "$1" == "toggle" ]; then
    if [ -z "$MODE" ]; then
        notify-send -a Battery "Long Life isn't supported on $BATTERY"
        exit 1
    fi
    [ "$MODE" == "Long_Life" ] && NEW=Standard || NEW=Long_Life
    if echo "$NEW" > "$DIR/charge_types" 2>/dev/null; then
        [ "$NEW" == "Long_Life" ] && MSG="Long Life on (holds ~60%)" || MSG="Long Life off (charges to 100%)"
        notify-send -a Battery "$MSG"
    else
        notify-send -u critical -a Battery "Couldn't change the charge mode" \
            "$DIR/charge_types isn't writable. Is the udev rule installed?"
    fi
    pkill -RTMIN+9 waybar
    exit 0
fi

CAPACITY=$(cat "$DIR/capacity")
STATUS=$(cat "$DIR/status")
ENERGY_NOW=$(cat "$DIR/energy_now" 2>/dev/null || echo 0)
ENERGY_FULL=$(cat "$DIR/energy_full" 2>/dev/null || echo 0)
POWER_NOW=$(cat "$DIR/power_now" 2>/dev/null || echo 0)

CLASSES=("level-$(( (CAPACITY + 10) / 20 * 20 ))")
case "$STATUS" in
    Charging) CLASSES+=(charging) ;;
    Full|"Not charging") CLASSES+=(plugged) ;;
    *)
        if [ "$CAPACITY" -le 15 ]; then
            CLASSES+=(critical)
        elif [ "$CAPACITY" -le 30 ]; then
            CLASSES+=(warning)
        fi
        ;;
esac
[ "$MODE" == "Long_Life" ] && CLASSES+=(longlife)

TOOLTIP="$STATUS"
if [ "$POWER_NOW" -gt 0 ]; then
    if [ "$STATUS" == "Discharging" ]; then
        MINUTES=$(( ENERGY_NOW * 60 / POWER_NOW ))
        TOOLTIP+=", $((MINUTES / 60))h $((MINUTES % 60))m left"
    elif [ "$STATUS" == "Charging" ]; then
        MINUTES=$(( (ENERGY_FULL - ENERGY_NOW) * 60 / POWER_NOW ))
        TOOLTIP+=", full in $((MINUTES / 60))h $((MINUTES % 60))m"
    fi
fi
case "$MODE" in
    Long_Life) TOOLTIP+="\nLong Life on (holds ~60%)" ;;
    Standard) TOOLTIP+="\nLong Life off" ;;
esac
[ -n "$MODE" ] && TOOLTIP+="\nClick to toggle Long Life"

jq -cn --arg text "$CAPACITY%" --arg tooltip "$(echo -e "$TOOLTIP")" \
    --argjson percentage "$CAPACITY" --args '{$text, $tooltip, $percentage, class: $ARGS.positional}' \
    "${CLASSES[@]}"
