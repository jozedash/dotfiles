#!/usr/bin/env bash
#
# Regenerates .config/waybar/icons from papirus-icon-theme (installed by
# setup.sh; it's also the desktop icon theme), recoloured to the bar text colour.
#
# Usage: setup/waybar-icons.sh [papirus root] [out dir]
set -e
REPO=$(cd "$(dirname "$0")/.." && pwd)
P=${1:-/usr/share/icons/Papirus}; OUT=${2:-$REPO/.config/waybar/icons}; C='#d8dee9'
mkdir -p "$OUT"
put() { # name source
    local src=$(readlink -f "$P/16x16/$2")
    [ -f "$src" ] || { echo "missing $2" >&2; exit 1; }
    # Drop the colour-scheme stylesheet and paint everything the bar colour
    sed -e '/<defs>/,/<\/defs>/d' -e "s/fill:currentColor/fill:$C/g" -e "s/fill:#ffffff/fill:$C/g" \
        -e 's/ class="[^"]*"//g' "$src" > "$OUT/$1.svg"
}
s=symbolic
put arch apps/distributor-logo-archlinux.svg
sed -i '/<circle/d' "$OUT/arch.svg"
for l in 000 020 040 060 080 100; do
    put battery-$l panel/battery-$l.svg
    put battery-$l-charging panel/battery-$l-charging.svg
    put battery-$l-longlife panel/battery-$l-profile-powersave.svg
    put battery-$l-charging-longlife panel/battery-$l-charging-profile-powersave.svg
done
for v in low medium high muted; do put volume-$v $s/status/audio-volume-$v-symbolic.svg; done
put brightness $s/status/display-brightness-symbolic.svg
put wifi $s/status/network-wireless-signal-excellent-symbolic.svg
put ethernet $s/devices/network-wired-symbolic.svg
put disconnected $s/status/network-offline-symbolic.svg
put bluetooth-on $s/status/bluetooth-active-symbolic.svg
put bluetooth-off $s/status/bluetooth-disabled-symbolic.svg
put bluetooth-connected $s/status/bluetooth-paired-symbolic.svg
put eye $s/actions/view-reveal-symbolic.svg
put eye-off $s/actions/view-conceal-symbolic.svg
put clipboard $s/actions/edit-paste-symbolic.svg
put colorpicker $s/actions/color-select-symbolic.svg
put palette $s/categories/applications-graphics-symbolic.svg
put cpu $s/devices/cpu-symbolic.svg
put memory $s/devices/memory-symbolic.svg
put disk $s/devices/drive-harddisk-symbolic.svg
put temperature $s/status/sensors-temperature-symbolic.svg
put weather $s/status/weather-few-clouds-symbolic.svg
put bell $s/status/notification-inactive-symbolic.svg
put bell-badge $s/status/notification-new-symbolic.svg
put dnd $s/status/notifications-disabled-symbolic.svg
put updates $s/status/software-update-available-symbolic.svg
put reboot $s/actions/system-reboot-symbolic.svg
put shield $s/status/security-high-symbolic.svg
put usb $s/devices/drive-removable-media-usb-pendrive-symbolic.svg
