#!/usr/bin/env bash

STATEFILE="$HOME/.config/hypr/layout_state"
set -x
# Add layouts here
LAPTOP=0
DOCKED=1
EXTEND=2
GAMING=3
MODE_COUNT=4 # Used to ensure the loop resets

if [ ! -f "$STATEFILE" ]; then
    # init to laptop only
    echo $LAPTOP > "$STATEFILE"
fi

# Read existing state
STATE=$(cat "$STATEFILE")

# Default back to laptop if no external monitor
if ! hyprctl monitors | grep -q "Monitor DP-2"; then
    if [ $STATE -ne $LAPTOP ]; then
        STATE=$LAPTOP
    fi
else
    # Toggle to next state if requested
    if [ "$1" == "toggle" ]; then
        STATE="$((STATE + 1))"

        # Reset to default
        if [ $STATE -ge $MODE_COUNT ]; then
            STATE=$LAPTOP
        fi
fi

if [ $STATE -eq $DOCKED ]; then
    # Switch to docked
    hyprctl keyword monitor "eDP-1,disable"
    hyprctl keyword monitor "DP-2,3840x2160@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 DP-2
    hyprctl dispatch moveworkspacetomonitor 2 DP-2
    hyprctl dispatch moveworkspacetomonitor 3 DP-2
    hyprctl dispatch moveworkspacetomonitor 4 DP-2
    hyprctl dispatch moveworkspacetomonitor 5 DP-2
    hyprctl dispatch moveworkspacetomonitor 6 DP-2
elif [ $STATE -eq $GAMING ]; then
    # Lower resolution
    hyprctl keyword monitor "eDP-1,disable"
    hyprctl keyword monitor "DP-2,1600x900@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 DP-2
    hyprctl dispatch moveworkspacetomonitor 2 DP-2
    hyprctl dispatch moveworkspacetomonitor 3 DP-2
    hyprctl dispatch moveworkspacetomonitor 4 DP-2
    hyprctl dispatch moveworkspacetomonitor 5 DP-2
    hyprctl dispatch moveworkspacetomonitor 6 DP-2
elif [ $STATE -ne $EXTEND ]; then
    # Extend
    hyprctl keyword monitor "eDP-1,1920x1080@60,3840x1080,1"
    hyprctl keyword monitor "DP-2,3840x2160@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 DP-2
    hyprctl dispatch moveworkspacetomonitor 2 eDP-1
    hyprctl dispatch moveworkspacetomonitor 3 DP-2
    hyprctl dispatch moveworkspacetomonitor 4 eDP-1
    hyprctl dispatch moveworkspacetomonitor 5 DP-2
    hyprctl dispatch moveworkspacetomonitor 6 eDP-1
elif [ $STATE -ne $LAPTOP ]; then
    # Laptop only
    hyprctl keyword monitor "eDP-1,1920x1080@60,0x0,1"
    hyprctl keyword monitor "DP-2,disable"
    hyprctl dispatch moveworkspacetomonitor 1 eDP-1
    hyprctl dispatch moveworkspacetomonitor 2 eDP-1
    hyprctl dispatch moveworkspacetomonitor 3 eDP-1
    hyprctl dispatch moveworkspacetomonitor 4 eDP-1
    hyprctl dispatch moveworkspacetomonitor 5 eDP-1
    hyprctl dispatch moveworkspacetomonitor 6 eDP-1
fi

echo $STATE > "$STATEFILE"