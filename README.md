# dotfiles

Archlinux dotfiles

### Contents

* [Philosophy](#philosophy)
* [Install](#install)
* [Manual setup](#manual-setup)
* [Dual boot config](#dual-boot-config-if-used)
* [Setup terminal login](#setup-terminal-login-optional-cooler)
* [Desktop config](#desktop-config)
* [Basic apps, config, security](#basic-apps-fonts-and-security)
* [Theme](#theme)
* [Updates](#updates)
* [Hibernate](#hibernate)
* [Security scan](#security-scan)
* [Repo layout](#repo-layout)
* [What isn't in git](#what-isnt-in-git)
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

Boot from your ISO USB, it'll load into a terminal.

Immediately, network needs configuration:

	iwctl
	station wlan0 connect XXXX

Then, move on to running the archinstall script

	pacman -Sy archinstall
	archinstall

The script changes fairly frequently, so work thorugh the options and find the corresponding settings:

* Set region and locale
* Set mirrors
* Disk config
	* Best effort partition layout
	* ext4
* Add root pwd
* Add user
* Set profile
	* Desktop
	* Hyprland
		* polkit
* BT config enabled
* Audio config
	* pipewire
* Copy network config to installation
* Additional packages (use / to search)
	* hyprpaper
	* waybar
	* kitty
	* wofi

## Manual setup:
* [Whatsapp](https://web.whatsapp.com/)
* [Minecraft](https://wiki.archlinux.org/title/Minecraft)

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

	sudo ./setup.sh

This installs the packages, links the user configs into `~` (`link.sh`), copies
the system files into `/etc` and `/usr`, enables the timers, sets up
hibernation (`setup/hibernate.sh`), the firewall and SSH, and runs rkhunter.
It also installs [Steam](https://wiki.archlinux.org/title/Steam): it enables the
`multilib` repo in `/etc/pacman.conf` (backed up first) and picks the 32-bit
Vulkan driver for the GPU (AMD or Intel; NVIDIA needs its driver installed by hand).

It's safe to run again, e.g. after pulling changes. Output is logged to
`/var/log/dotfiles-setup/`, and a summary at the end lists any steps that failed.
A failed system update stops it straight away, since installing packages on
top would be a partial upgrade.

### Theme

All colours come from one theme: an accent pair (primary + secondary) and a
dark or light mode. No third-party themes; GTK builds on stock Adwaita.

* Click the palette icon on the bar for the picker: click one square for the
  primary, then another for the secondary. Up to 3 favourite pairs (star the
  current pair; right-click a favourite to remove it). Escape or clicking
  elsewhere closes it.
* Right-click the icon for the next favourite; middle-click, or Super+Shift+T,
  toggles dark/light.
* From a terminal: `~/.config/theme/theme-apply --pair '#ff00ff' '#8800ff'`,
  `--mode light`, `--toggle-mode`, ... (`--help` lists them).

Everything follows live: Hyprland borders, hyprlock, waybar, wofi, swaync,
fcitx5, kitty, fastfetch, the wallpaper (cherry blossoms at Jiming Temple in
light mode, Hongya Cave at night in dark; credits in
`.config/hypr/wallpapers/CREDITS.md`), GTK apps (Thunar, file pickers), libadwaita apps, Qt apps
(through `QT_QPA_PLATFORMTHEME=gtk3`), Firefox (dark/light), and the Papirus
icons (dark/light). libadwaita apps show a new pair when next started.

How it works: the choice is saved in `~/.local/state/dotfiles-theme/state.json`.
`.config/theme/theme-apply` renders each program's colour file from
`.config/theme/templates/` and tells running programs to reload. The GTK3
theme is Adwaita's own CSS recoloured to our palette, under a new
`~/.local/share/themes/Hypr-*` name each time (GTK3 only restyles running apps
when the name changes). Dark mode follows VS Code's dark greys; the palettes
and terminal colours are in `.config/theme/theme.py`, the picker's squares in
`.config/theme/palette.json`.

To theme another program: add a template using `@primary@`-style
placeholders (see `palette()` in `theme.py` for the names), a `Target` line
in `theme-apply`, and its reload command in `RELOADS`.

### Hibernate

* Super+Shift+H (or `systemctl hibernate`) hibernates now. Save your work first: if resuming
  fails, the laptop boots fresh and unsaved work is lost (nothing else is harmed).
* Closing the lid on battery suspends, then hibernates after 2 hours. On the
  charger it only suspends; with an external monitor connected it does nothing.
* After 30 minutes idle, hypridle does the same suspend-then-hibernate.

### Updates

Updates are downloaded automatically but installed by hand:

* `pacman-download.timer` runs weekly (catching up after the laptop was off). It
  downloads pending updates into the pacman cache with `checkupdates -d`, which
  uses a temporary copy of the databases, so it can't cause a partial upgrade.
  It also notes any Arch news posted since the last run.
* You then get a notification, and the waybar updates icon shows how many are
  waiting. The tooltip lists them, the news, and any `.pacnew` files.
* Click the icon or press Super+U to run `sudo pacman -Syu`. A reboot icon shows
  when the kernel was upgraded.
* If a download fails, the notification points to
  [docs/pacman-download-failures.md](docs/pacman-download-failures.md).
* `paccache.timer` keeps the last 3 versions of each package in the cache.

To download now: `sudo systemctl start pacman-download.service`.

### Security scan

`security-scan.timer` runs `/usr/local/bin/security-scan` as root once a week,
alongside the update download (catching up after the laptop was off). It takes a
few minutes at low priority. Each check writes one line per finding:

| Finding | Meaning | What to do |
|---|---|---|
| `firewall:` | ufw isn't active | `sudo ufw enable && sudo systemctl enable ufw` |
| `port:` | Something listens on a non-loopback address | Find it with `sudo ss -tulpn`; stop or firewall it if you don't need it |
| `cve:` | An installed package has a known vulnerability (`arch-audit`) | Update; if no fix exists yet, decide whether you need the package |
| `altered:` | A package file differs from the signed package (`pacman -Qkk`) | Reinstall the package (`sudo pacman -S <pkg>`); if you didn't change it, investigate |
| `unowned:` | An executable or systemd unit no package installed | Expected for this repo's files in `/usr/local/bin` and `/etc/systemd/system`; anything else, find out where it came from |
| `foreign:` | A package not from the repos (AUR, or dropped from Arch) | Gets no updates from pacman; remove it if unneeded |
| `rkhunter:` | rkhunter warning | Details in `/var/log/rkhunter.log` |

* You get a critical notification (`security-scan-notify.path`) listing findings
  that weren't in the previous scan, so each one only alerts once. The first scan
  reports everything.
* `/var/lib/security-scan/report` has every current finding plus the full output
  of each check; `findings` and `new` hold the last scan's and the new lines.
* rkhunter's file properties check is skipped: it flags every file an update
  changes until `rkhunter --propupd`. `pacman -Qkk` checks the same files against
  the signed packages instead.
* The script and units are copied into `/usr` and `/etc` by `setup.sh`, not
  linked like the user configs: a root-run script that links back into your home
  could be edited by anything running as you. After editing them, run
  `sudo ./setup.sh` again.

To scan now: `sudo systemctl start security-scan.service`, then
`cat /var/lib/security-scan/report`.

## Repo layout

| Path | What | Installed by |
|---|---|---|
| `.config/`, `.bash_profile` | User config, generic | Linked into `~` by `link.sh` |
| `etc/`, `usr/` | System config, generic | Copied by `setup.sh` |
| `hosts/<model>/` | Settings for one machine, named after `/sys/class/dmi/id/product_version` with spaces as `-` | `~/.config/dotfiles-host` links here; `hosts/<model>/etc/` is copied after `etc/` |
| `setup/` | Helper scripts (hibernation, regenerating the waybar icons) | `setup.sh` |
| `docs/`, `plans/` | Troubleshooting guides and change plans | |

On a machine without a `hosts/` folder, the battery and backlight modules are
simply hidden, and `toggle_layout.sh` uses its built-in defaults.

## What isn't in git

| Item | Why | Source |
|---|---|---|
| `/home/swapfile`, its fstab line, `resume=`/`resume_offset=` in the boot entry | Unique to each disk and partition | `setup/hibernate.sh` |
| `/boot/loader/entries/*.conf` | Created by archinstall with this machine's PARTUUID | Edited in place by `setup/hibernate.sh` |
| Long Life on/off | Stored in the laptop's firmware | Battery icon click |
| `~/.local/state/hypr/layouts/` | Remembered layout per monitor setup | `toggle_layout.sh` |
| `fcitx5/conf/cached_layouts`, pinyin user dictionary | Generated cache, personal typing history | fcitx5 (`.gitignore`) |
| `~/.local/state/dotfiles-theme/state.json` | Chosen accent pair, mode and favourites | `~/.config/theme/theme-apply` |
| Colour files (`waybar/colors.css`, `wofi/style.css`, `hypr/colors.lua`, ...), `~/.local/share/fcitx5/themes/hypr/`, the GTK3 theme `~/.local/share/themes/Hypr-*`, `~/.config/gtk-{3,4}.0/` settings and CSS, `~/.config/fastfetch/config.jsonc` | Generated from `.config/theme/templates/` for the current theme | `theme-apply`, also run by `link.sh` (`.gitignore`) |
| `/var/lib/iwd/*.psk` | Wifi passwords | `impala` (or `iwctl`) |
| `/var/lib/pacman-download/` | Runtime state | Update timer |
| `/var/lib/security-scan/` | Last scan's findings and report | Security scan timer |