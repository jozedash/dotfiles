#!/usr/bin/env bash
#
# Symlink configs from this repo into $HOME, so edits to the live config are edits
# to the checkout (no second copy to keep in sync).
#
# Usage: ./link.sh [path...]   e.g. ./link.sh .config/hypr
#   With no arguments every path in LINKS is linked, plus ~/.config/dotfiles-host
#   -> hosts/<model>/ when this machine has a host folder. Anything already at the
#   target that isn't the right symlink is moved aside to <target>.bak-<timestamp>.
#   Run as your user, not with sudo.

# Paths relative to both the repo root and $HOME
LINKS=(.bash_profile .config/hypr .config/waybar .config/wofi .config/fcitx5
    .config/swaync .config/udiskie .config/fontconfig .config/systemd/user
    .config/theme .config/kitty)

REPO=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date '+%Y-%m-%d_%H:%M:%S')

# Machine model, e.g. "Yoga 6 13ARE05" -> hosts/Yoga-6-13ARE05
HOST=$(tr ' ' '-' < /sys/class/dmi/id/product_version 2>/dev/null)

link() { # src dest
    local SRC=$1 DEST=$2

    if [ ! -e "$SRC" ]; then
        echo "Skipping $SRC: not in repo"
        return
    fi
    if [ "$(readlink "$DEST")" == "$SRC" ]; then
        echo "Already linked: $DEST"
        return
    fi
    if [ -e "$DEST" ] || [ -L "$DEST" ]; then
        echo "Backing up $DEST -> $DEST.bak-$STAMP"
        mv "$DEST" "$DEST.bak-$STAMP"
    fi

    mkdir -p "$(dirname "$DEST")"
    ln -s "$SRC" "$DEST"
    echo "Linked $DEST -> $SRC"
}

if [ $# -gt 0 ]; then
    LINKS=("$@")
elif [ -n "$HOST" ] && [ -d "$REPO/hosts/$HOST" ]; then
    link "$REPO/hosts/$HOST" "$HOME/.config/dotfiles-host"
else
    echo "No host folder for '$HOST', skipping ~/.config/dotfiles-host"
fi

for LINK in "${LINKS[@]}"; do
    link "$REPO/$LINK" "$HOME/$LINK"
done

# Write the colour files the configs import (see .config/theme/theme-apply)
"$REPO/.config/theme/theme-apply" --no-reload ||
    echo "theme-apply failed: waybar, wofi and swaync will be missing their colours"
