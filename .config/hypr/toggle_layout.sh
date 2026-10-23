#!/usr/bin/env bash
#
# Usage: toggle_layout.sh [apply|hotplug|toggle|prev|laptop|docked|extend|gaming]
#   apply (default) - apply the remembered layout for the currently connected monitors
#   hotplug         - like apply, but only acts if the set of connected outputs changed
#   toggle / prev   - cycle forwards / backwards through the layouts
#   <layout>        - jump straight to that layout
#
# The chosen layout is remembered per monitor setup (keyed on the external monitors'
# descriptions), so e.g. the home and office monitors each keep their own layout.

STATEDIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/layouts"
RUNDIR="${XDG_RUNTIME_DIR:-/tmp}"
LAPTOP_OUTPUT="eDP-1"
LAPTOP_MODE="1920x1080@60"
GAMING_MODE="1600x900@60"
# set -x

# Add layouts here, in the order toggle cycles through them
LAYOUTS=(laptop docked extend gaming)
DEFAULT_LAYOUT=extend # Used the first time a new monitor setup is seen

mkdir -p "$STATEDIR"

# Keybind/hotplug runs have no terminal, so keep a log for debugging
exec > >(tee -a "$RUNDIR/hypr_toggle_layout.log") 2>&1
echo "=== $(date '+%F %T') toggle_layout.sh $*"

# Serialise keybind and hotplug invocations
exec 9>"$RUNDIR/hypr_toggle_layout.lock"
flock 9

# Let outputs settle after a plug/unplug (docks can bounce)
if [ "$1" == "hotplug" ]; then
    sleep 1
fi

MONITORS_JSON=$(hyprctl -j monitors all)
EXTERNALS_JSON=$(jq -c --arg laptop "$LAPTOP_OUTPUT" \
    '[.[] | select(.name != $laptop and (.name | test("^(FALLBACK|HEADLESS)") | not))]' \
    <<< "$MONITORS_JSON")

mapfile -t EXTERNALS < <(jq -r '.[].name' <<< "$EXTERNALS_JSON")
MONITOR=${EXTERNALS[0]}
SETUP=$(jq -r '.[].description | select(. != "")' <<< "$EXTERNALS_JSON" | sort | tr -c '[:alnum:]\n' '_' | paste -sd+)

# Skip hotplug events that didn't change what's connected, e.g. the ones fired
# by this script enabling/disabling outputs
OUTPUTS=$(jq -r '.[].name' <<< "$MONITORS_JSON" | sort | paste -sd,)
if [ "$1" == "hotplug" ] && [ "$OUTPUTS" == "$(cat "$RUNDIR/hypr_layout_outputs" 2>/dev/null)" ]; then
    echo "Outputs unchanged ($OUTPUTS), nothing to do"
    exit 0
fi
echo "$OUTPUTS" > "$RUNDIR/hypr_layout_outputs"

if [ -z "$MONITOR" ]; then
    # Nothing else is possible, and the remembered layouts are left untouched
    echo "No external monitor!"
    LAYOUT=laptop
else
    echo "Found external monitor(s): ${EXTERNALS[*]} (setup: $SETUP)"
    STATEFILE="$STATEDIR/$SETUP"
    LAYOUT=$(cat "$STATEFILE" 2>/dev/null)

    INDEX=-1
    for i in "${!LAYOUTS[@]}"; do
        [ "${LAYOUTS[$i]}" == "$LAYOUT" ] && INDEX=$i
    done
    if [ $INDEX -lt 0 ]; then
        LAYOUT=$DEFAULT_LAYOUT
        for i in "${!LAYOUTS[@]}"; do
            [ "${LAYOUTS[$i]}" == "$LAYOUT" ] && INDEX=$i
        done
    fi

    case "$1" in
        toggle)
            LAYOUT=${LAYOUTS[$(( (INDEX + 1) % ${#LAYOUTS[@]} ))]} ;;
        prev)
            LAYOUT=${LAYOUTS[$(( (INDEX - 1 + ${#LAYOUTS[@]}) % ${#LAYOUTS[@]} ))]} ;;
        laptop|docked|extend|gaming)
            LAYOUT=$1 ;;
    esac

    echo "$LAYOUT" > "$STATEFILE"

    # Use the external monitor's best mode (first listed) rather than assuming 4K
    EXT_MODE=$(jq -r '.[0].availableModes[0] // "preferred"' <<< "$EXTERNALS_JSON" | sed 's/Hz$//')
    EXT_W=$(grep -oP '^\d+(?=x)' <<< "$EXT_MODE")
    EXT_H=$(grep -oP '^\d+x\K\d+' <<< "$EXT_MODE")
    if ! jq -e --arg m "$GAMING_MODE" '.[0].availableModes | map(sub("\\.\\d+Hz$"; "")) | index($m)' \
        <<< "$EXTERNALS_JSON" > /dev/null; then
        GAMING_MODE=$EXT_MODE
    fi
fi
echo "Applying layout: $LAYOUT"

monitor_on() { # output mode position
    hyprctl eval "hl.monitor({
        output = \"$1\",
        mode = \"$2\",
        position = \"$3\",
        scale = 1,
        disabled = false
    })" > /dev/null
}

monitor_off() { # output
    hyprctl eval "hl.monitor({
        output = \"$1\",
        disabled = true
    })" > /dev/null
}

move_workspaces() { # one output per workspace, starting from workspace 1
    local ws=1
    for output in "$@"; do
        hyprctl dispatch "hl.dsp.workspace.move({
            workspace = $ws,
            monitor = \"$output\"
        })" > /dev/null
        ws=$((ws + 1))
    done
}

# Outputs are always enabled before others are disabled, so there is never a
# moment with no active output (which is what causes the black screen)
case "$LAYOUT" in
    docked)
        monitor_on "$MONITOR" "$EXT_MODE" "0x0"
        move_workspaces "$MONITOR" "$MONITOR" "$MONITOR" "$MONITOR" "$MONITOR" "$MONITOR"
        monitor_off "$LAPTOP_OUTPUT"
        ;;
    gaming)
        # Lower resolution
        monitor_on "$MONITOR" "$GAMING_MODE" "0x0"
        move_workspaces "$MONITOR" "$MONITOR" "$MONITOR" "$MONITOR" "$MONITOR" "$MONITOR"
        monitor_off "$LAPTOP_OUTPUT"
        ;;
    extend)
        # Laptop sits bottom-right of the external monitor
        monitor_on "$MONITOR" "$EXT_MODE" "0x0"
        monitor_on "$LAPTOP_OUTPUT" "$LAPTOP_MODE" "${EXT_W:-1920}x$(( ${EXT_H:-1080} - 1080 ))"
        move_workspaces "$MONITOR" "$LAPTOP_OUTPUT" "$MONITOR" "$LAPTOP_OUTPUT" "$MONITOR" "$LAPTOP_OUTPUT"
        ;;
    laptop)
        monitor_on "$LAPTOP_OUTPUT" "$LAPTOP_MODE" "0x0"
        L=$LAPTOP_OUTPUT
        move_workspaces "$L" "$L" "$L" "$L" "$L" "$L"
        for output in "${EXTERNALS[@]}"; do
            monitor_off "$output"
        done
        ;;
esac

# Waybar doesn't re-anchor its bars when outputs move or switch off, so restart it.
# Skipped at startup (no argument), where hyprland.lua launches waybar itself.
if [ -n "$1" ] && pgrep -x waybar > /dev/null; then
    pkill -x waybar
    for _ in {1..20}; do
        pgrep -x waybar > /dev/null || break
        sleep 0.1
    done
    # 9>&- so waybar doesn't inherit (and hold) the lock
    setsid -f waybar > /dev/null 2>&1 9>&-
fi

if [ -n "$1" ] && [ "$1" != "apply" ]; then
    hyprctl notify -1 1500 0 "Display layout: $LAYOUT" > /dev/null
fi
