# dotfiles
Archlinux dotfiles

Philosophy:
Official pacman-only repos (no AUR)
Minimal manual installs
Simple, common configs
All doable via 
	archinstall
	github shell script
	github dotfiles
New system up and running in an hour

Install:
TODO - detailed options

	iwctl
	station wlan0 connect XXXX

	pacman -Sy archinstall

	archinstall

	normal settings
	+hyprpaper
	+waybar
	+kitty
	+wofi
	+pipewire-audio
	+pipewire-pulse
	+wireplumber
	+pavucontrol
	+thunar/dolphin/pcmanfm =====PICK ONE
	+screenfetch
	+gnome-text-editor ====RESEARCH OPTIONS
	+hyprshot
	+swaync
	+hyprlock
	+hypridle

TODO:
	Steam
	Whatsapp
	Email?
	Surfshark
	Discord
	Wofi prettification
	Keyboard Fn keys
	

Dual boot config (if used)

	reboot (into mint)

	sudo os-prober
	sudo update-grub

	reboot (now an option for arch, note which entry it is)

	Launch your main OS
	
	sudo nano /etc/default/grub
	Change GRUB_DEFAULT=0 to the index of your arch option (e.g. number 3 in the list => index 2)
	sudo update-grub
	
	reboot
	
	Now you'll default into arch

	Login

	ctrl+alt+f3 open terminal

Setup terminal login (optional (cooler))

	sudo systemctl disable sddm
	sudo systemctl set-default multi-user.target
	sudo nano ~/.bash_profile
	Add the following to the bottom of the file:

	if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
	  export XDG_CURRENT_DESKTOP=Hyprland
	  export XDG_SESSION_TYPE=wayland
	  exec Hyprland
	fi


Desktop Config:
TODO - Use my dotfiles

Basic apps
TODO - Script it
TODO - research others' default apps
TODO - widgets
TODO - pacman -Qe

	sudo pacman -Syu  # Run weekly
	sudo pacman -S gnome-themes-extra # what's this for?
	sudo pacman -S ttf-fira-code ttf-nerd-fonts-symbols ttf-font-awesome ttf-arphic-ukai ttf-arphic-uming ttf-dejavu ttf-freefont noto-fonts # fonts for the UI
	sudo pacman lxappearance

Security:
TODO - anything else needed?

	sudo pacman -S ufw # Firewall
	sudo ufw default deny incoming
	sudo ufw default allow outgoing
	sudo ufw enable

	sudo nano /etc/ssh/sshd_config #
	PermitRootLogin no
	PasswordAuthentication no
	AllowUsers yourusername

	sudo pacman -S rkhunter
	sudo rkhunter --check
	
	
VPN
	sudo pacman -Syu wireguard-tools
	sudo pacman -S nm-connection-editor network-manager-applet networkmanager
	sudo systemctl enable NetworkManager
	sudo systemctl enable wpa_supplicant
	sudo systemctl start NetworkManager
	sudo systemctl start wpa_supplicant
