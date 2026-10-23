#!/bin/bash
# set -x

# Run with `sudo ./pacman_install.sh $(whoami)`
if [ -z "$1" ]; then
	echo "No user provided!"
	exit 1
else
	echo "Username $1"
fi

# Update all
pacman -Syu

# TODO - mod /etc/pacman.conf for steam

# Install modules
MODULES=("pipewire-audio" "pipewire-pulse" "wireplumber" "pavucontrol" "thunar" "fastfetch" "gnome-text-editor" "gnome-keyring" "unzip" "hyprshot" "swaync" "hyprlock" "hypridle" "lxappearance" "ufw" "rkhunter" "thunderbird" "polkit" "hyprpolkitagent" "fcitx5-rime" "fcitx5-im" "fcitx5-chinese-addons" "fcitx5-pinyin-zhwiki" "fcitx5-configtool" "btop" "keepassxc" "brightnessctl" "libreoffice-still" "ffmpeg" "7zip" "jq" "poppler" "fd" "ripgrep" "fzf" "zoxide" "resvg" "imagemagick" "yazi" "libimobiledevice" "usbmuxd" "kid3" "ifuse" "tlp" "vlc-plugin-dvb")

MODULE_NO=0
for MODULE in ${MODULES[@]}; do
	echo $MODULE
	MODULE_NO=$((MODULE_NO+1))
	if ! pacman -S --needed --noconfirm $MODULE; then
		echo "Module ${MODULE_NO} failed to install!"
		exit 1
	fi
done

# Install fonts
FONTS=("gnome-themes-extra" "ttf-fira-code" "ttf-nerd-fonts-symbols" "ttf-font-awesome" "ttf-arphic-ukai" "ttf-arphic-uming" "ttf-dejavu" "ttf-freefont" "noto-fonts")

FONT_NO=0
for FONT in ${FONTS[@]}; do
	echo $FONT
	FONT_NO=$((FONT_NO+1))
	if ! pacman -S --needed --noconfirm $FONT; then
		echo "Font ${FONT_NO} failed to install!"
		exit 1
	fi
done


# Run from the repo root so the relative paths below resolve
cd "$(dirname "$0")"

# Config file permissions
chmod 755 ./.config/hypr/toggle_layout.sh ./link.sh

# Symlink user configs into place (as the user, so they own them)
sudo -H -u "$1" ./link.sh

# Copy system files to correct locations
cp -r ./usr/. /usr/
cp ./etc/tlp.conf /etc/tlp.conf
systemctl enable --now tlp

# Do security
ufw default deny incoming
ufw default allow outgoing
ufw enable

dt=`date '+%Y-%m-%d_%H:%M:%S'`
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bkp_$dt

sed -i 's/^[#[:space:]]*PermitRootLogin[[:space:]]\+.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^[#[:space:]]*PasswordAuthentication[[:space:]]\+.*/PasswordAuthentication no/' /etc/ssh/sshd_config
echo AllowUsers $1 >> /etc/ssh/sshd_config

pacman -S rkhunter
rkhunter --check

exit 0	
