#!/usr/bin/env bash
#
# Waybar module for the weekly pacman-download timer. Shows the number of
# downloaded updates that still aren't installed, a reboot icon when the running
# kernel has been upgraded, and a shield when only .pacnew files are left to
# merge. Prints nothing (hiding the module) when there's nothing to do.

STATE=/var/lib/pacman-download
# The repo, through the ~/.config symlink this script is run from
DOCS=$(readlink -f "$(dirname "$0")/../../..")/docs

# pending lines look like "linux 7.2.10.arch1-1 -> 7.2.11.arch1-1"
UPDATES=()
while read -r PKG _ _ NEW; do
    [ -n "$NEW" ] || continue
    INSTALLED=$(pacman -Q "$PKG" 2>/dev/null | cut -d' ' -f2) || continue
    [ "$(vercmp "$INSTALLED" "$NEW")" -lt 0 ] && UPDATES+=("$PKG $INSTALLED -> $NEW")
done < <(cat "$STATE/pending" 2>/dev/null)

mapfile -t PACNEW < <(command -v pacdiff > /dev/null && pacdiff -o 2>/dev/null)
REBOOT=false
[ -d "/usr/lib/modules/$(uname -r)" ] || REBOOT=true

TOOLTIP=""
if [ ${#UPDATES[@]} -gt 0 ]; then
    TOOLTIP+="${#UPDATES[@]} updates downloaded (click to install):\n$(printf '%s\n' "${UPDATES[@]}")"
fi
if [ -s "$STATE/news" ]; then
    TOOLTIP+="\n\nArch news:\n$(cat "$STATE/news")"
fi
if [ ${#PACNEW[@]} -gt 0 ]; then
    TOOLTIP+="\n\nConfig files to merge (sudo pacdiff):\n$(printf '%s\n' "${PACNEW[@]}")"
fi
if $REBOOT; then
    TOOLTIP+="\n\nThe kernel was upgraded: reboot to load the new one"
fi
if [ -s "$STATE/error" ]; then
    TOOLTIP+="\n\nLast download failed, see $DOCS/pacman-download-failures.md:\n$(cat "$STATE/error")"
fi

if $REBOOT; then
    CLASS=reboot
    TEXT=${#UPDATES[@]}
    [ "$TEXT" -gt 0 ] || { TEXT=" "; CLASS+=" icon-only"; }
elif [ ${#UPDATES[@]} -gt 0 ]; then
    CLASS=updates
    TEXT=${#UPDATES[@]}
elif [ ${#PACNEW[@]} -gt 0 ]; then
    CLASS=pacnew
    TEXT=${#PACNEW[@]}
else
    exit 0
fi

jq -cn --arg text "$TEXT" --arg tooltip "$(echo -e "$TOOLTIP" | sed '/./,$!d')" --arg class "$CLASS" '{$text, $tooltip, class: ($class / " ")}'
