#!/usr/bin/env bash

STATEFILE="$HOME/.config/hypr/layout_state"
set -x
# Add layouts here
layouts=("gaming" "docked" "extend")

if [ ! -f "$STATEFILE" ]; then
    # init to 0
    echo "0" > "$STATEFILE"
fi

state=$(cat "$STATEFILE")

if [ "$1" == "toggle" ]; then
    state="$((state + 1))"

    if [ $state -ge ${#layouts[@]} ]; then
        state=0
    fi
fi

if [ ${layouts[$state]} = "docked" ]; then
    # Switch to docked
    hyprctl keyword monitor "eDP-1,disable"
    hyprctl keyword monitor "DP-2,3840x2160@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 DP-2
    hyprctl dispatch moveworkspacetomonitor 2 DP-2
    hyprctl dispatch moveworkspacetomonitor 3 DP-2
    hyprctl dispatch moveworkspacetomonitor 4 DP-2
    hyprctl dispatch moveworkspacetomonitor 5 DP-2
    hyprctl dispatch moveworkspacetomonitor 6 DP-2
elif [ ${layouts[$state]} = "gaming" ]; then
    # Lower resolution
    hyprctl keyword monitor "eDP-1,disable"
    hyprctl keyword monitor "DP-2,1600x900@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 DP-2
    hyprctl dispatch moveworkspacetomonitor 2 DP-2
    hyprctl dispatch moveworkspacetomonitor 3 DP-2
    hyprctl dispatch moveworkspacetomonitor 4 DP-2
    hyprctl dispatch moveworkspacetomonitor 5 DP-2
    hyprctl dispatch moveworkspacetomonitor 6 DP-2
elif [ ${layouts[$state]} = "extend" ]; then
    # Extend
    hyprctl keyword monitor "eDP-1,1920x1080@60,3840x1080,1"
    hyprctl keyword monitor "DP-2,3840x2160@60,0x0,1"
    hyprctl dispatch moveworkspacetomonitor 1 DP-2
    hyprctl dispatch moveworkspacetomonitor 2 eDP-1
    hyprctl dispatch moveworkspacetomonitor 3 DP-2
    hyprctl dispatch moveworkspacetomonitor 4 eDP-1
    hyprctl dispatch moveworkspacetomonitor 5 DP-2
    hyprctl dispatch moveworkspacetomonitor 6 eDP-1
fi

echo $state > "$STATEFILE"