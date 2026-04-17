#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
	export XDG_CURRENT_DESKTOP=Hyprland
	export XDG_SESSION_TYPE=wayland
	exec start-hyprland
fi
