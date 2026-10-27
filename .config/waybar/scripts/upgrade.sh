#!/usr/bin/env bash
# Install updates in a terminal (waybar updates icon, Super+U), then wait for a
# key so the result can be read before the window closes.

# The repo, through the ~/.config symlink this script is run from
DOCS=$(readlink -f "$(dirname "$0")/../../..")/docs

sudo pacman -Syu
STATUS=$?

echo
if [ $STATUS -eq 0 ]; then
    echo "Upgrade finished."
    [ -n "$(pacdiff -o 2>/dev/null)" ] && echo "Some config files need merging: sudo pacdiff"
    [ -d "/usr/lib/modules/$(uname -r)" ] || echo "The kernel was upgraded: reboot to use it."
else
    echo "Upgrade FAILED (exit code $STATUS), see the output above."
    echo "Help: $DOCS/pacman-download-failures.md"
fi
pkill -RTMIN+8 waybar
read -n 1 -s -r -p "Press any key to close"
