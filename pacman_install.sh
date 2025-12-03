#!/bin/bash
#/dolphin/pcmanfm =====PICK ONE
set -x

# Update all
pacman -Syu

# TODO - mod /etc/pacman.conf for steam

# Install modules
MODULES=("pipewire-audio" "pipewire-pulse" "wireplumber" "pavucontrol" "thunar" "fastfetch" "gnome-text-editor" "unzip" "hyprshot" "swaync" "hyprlock" "hypridle" "lxappearance" "ufw" "rkhunter" "thunderbird" "polkit" "hyprpolkitagent" "fcitx5-rime" "fcitx5-chinese-addons" "fcitx5-configtool" "btop" "keepassxc")

MODULE_NO=0
for MODULE in ${MODULES[@]}; do
	echo $MODULE
	pacman -Sy $MODULE --noconfirm
	MODULE_NO=$((MODULE_NO+1))
	if [ $? -ne 0 ]; then
		echo "Module ${MODULE_NO} failed to install!"
		exit 1
	fi
done

# Install fonts
FONTS=("gnome-themes-extra" "ttf-fira-code" "ttf-nerd-fonts-symbols" "ttf-font-awesome" "ttf-arphic-ukai" "ttf-arphic-uming" "ttf-dejavu" "ttf-freefont" "noto-fonts")

FONT_NO=0
for FONT in ${FONTS[@]}; do
	echo $FONT
	pacman -Sy $FONT --noconfirm
	FONT_NO=$((FONT_NO+1))
	if [ $? -ne 0 ]; then
		echo "Font ${FONT_NO} failed to install!"
		exit 1
	fi
done


# TODO - copy files to correct locations

# TODO - config file permissions

# Do security
ufw default deny incoming
ufw default allow outgoing
ufw enable

nano /etc/ssh/sshd_config #
PermitRootLogin no
PasswordAuthentication no
AllowUsers yourusername

pacman -S rkhunter
rkhunter --check

exit 0	
