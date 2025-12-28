#!/usr/bin/env bash

STATEFILE="$HOME/.config/hypr/layout_state"
# set -x

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

MONITOR=$(hyprctl monitors all | grep "(ID 1)" | grep -oP "DP-\d")
echo "Found second monitor on $MONITOR"

# Default back to laptop if no external monitor
if [ -z $MONITOR ]; then
    echo "No secondary monitor!"
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
fi

if [ $STATE -eq $DOCKED ]; then
    # Switch to docked
    hyprctl keyword monitor "eDP-1,disable"
    hyprctl keyword monitor "$MONITOR,3840x2160@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 2 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 3 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 4 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 5 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 6 $MONITOR
elif [ $STATE -eq $GAMING ]; then
    # Lower resolution
    hyprctl keyword monitor "eDP-1,disable"
    hyprctl keyword monitor "$MONITOR,1600x900@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 2 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 3 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 4 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 5 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 6 $MONITOR
elif [ $STATE -eq $EXTEND ]; then
    # Extendo
    hyprctl keyword monitor "eDP-1,1920x1080@60,3840x1080,1"
    hyprctl keyword monitor "$MONITOR,3840x2160@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 2 eDP-1
    hyprctl dispatch moveworkspacetomonitor 3 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 4 eDP-1
    hyprctl dispatch moveworkspacetomonitor 5 $MONITOR
    hyprctl dispatch moveworkspacetomonitor 6 eDP-1
elif [ $STATE -eq $LAPTOP ]; then
    # Laptop only
    hyprctl keyword monitor "eDP-1,1920x1080@60,0x0,1"
    hyprctl keyword monitor "$MONITOR,disable"
    hyprctl dispatch moveworkspacetomonitor 1 eDP-1
    hyprctl dispatch moveworkspacetomonitor 2 eDP-1
    hyprctl dispatch moveworkspacetomonitor 3 eDP-1
    hyprctl dispatch moveworkspacetomonitor 4 eDP-1
    hyprctl dispatch moveworkspacetomonitor 5 eDP-1
    hyprctl dispatch moveworkspacetomonitor 6 eDP-1
fi

echo $STATE > "$STATEFILE"