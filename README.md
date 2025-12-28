# dotfiles

Archlinux dotfiles

### Contents

* [Philosophy](#philosophy)
* [Install](#install)
* [Manual setup](#manual-setup)
* [Todo](#todo)
* [Dual boot config](#dual-boot-config-if-used)
* [Setup terminal login](#setup-terminal-login-optional-cooler)
* [Desktop config](#desktop-config)
* [Basic apps, config, security](#basic-apps-fonts-and-security)
* [VPN (wip)](#vpn-wip)

## Philosophy:

* Official pacman-only repos (no AUR)
* Minimal manual installs
* Simple, common configs

All doable via:

* archinstall
* github shell script
* github dotfiles

New system up and running in an hour

## Install:

TODO - detailed options

	iwctl
	station wlan0 connect XXXX

	pacman -Sy archinstall

	archinstall

	Normal settings

	Audio config
	+pipewire-audio
	+pipewire-pulse

	Add packages
	+hyprpaper
	+waybar
	+kitty
	+wofi

## Manual setup:
* [Steam](https://wiki.archlinux.org/title/Steam)
* [Whatsapp](https://web.whatsapp.com/)
* [Minecraft](https://wiki.archlinux.org/title/Minecraft)

## Todo
* Wofi prettification

## Dual boot config (if used):

reboot (into mint)

	sudo os-prober
	sudo update-grub

reboot (now an option for arch, note which entry it is)

Launch your main OS
	
	sudo nano /etc/default/grub

Change GRUB_DEFAULT=0 to the index of your arch option (e.g. number 3 in the list => index 2)
	
	sudo update-grub
	
1. reboot
2. Now you'll default into arch
3. Login
4. ctrl+alt+f3 open terminal

## Setup terminal login (optional (cooler))

	sudo systemctl disable sddm
	sudo systemctl set-default multi-user.target
	sudo nano ~/.bash_profile
	
Add the following to the bottom of the file:

	if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
	  export XDG_CURRENT_DESKTOP=Hyprland
	  export XDG_SESSION_TYPE=wayland
	  exec Hyprland
	fi

## Desktop Config:

### Basic apps, fonts, and security

TODO - widgets

	sudo pacman -Syu  # Run weekly
	sudo pacman_install.sh $(whoami)
	
### VPN (WIP)

	sudo pacman -Syu wireguard-tools
	sudo pacman -S nm-connection-editor network-manager-applet networkmanager
	sudo systemctl enable NetworkManager
	sudo systemctl enable wpa_supplicant
	sudo systemctl start NetworkManager
	sudo systemctl start wpa_supplicant
