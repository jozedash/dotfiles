#!/usr/bin/env bash
#
# Set up a fresh Arch install from this repo, or bring an existing one up to date.
# Safe to run again: every step checks or overwrites rather than appending.
#
# Usage: sudo ./setup.sh [user]
#   user: who the configs are linked for (default: whoever ran sudo)
#
# Everything is shown and also logged to /var/log/dotfiles-setup/<date>.log.
# A failed step doesn't stop the independent steps after it; the summary at
# the end lists every failure and where to find its output.

REPO=$(cd "$(dirname "$0")" && pwd)
cd "$REPO"

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo: sudo ./setup.sh"
    exit 1
fi

USER_NAME=${1:-$SUDO_USER}
if [ -z "$USER_NAME" ] || [ "$USER_NAME" == root ] || ! id "$USER_NAME" > /dev/null 2>&1; then
    echo "Couldn't work out which user to set up for ('$USER_NAME')."
    echo "Run it from your own account with sudo, or pass the user: sudo ./setup.sh <user>"
    exit 1
fi
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

# Machine model, e.g. "Yoga 6 13ARE05" -> hosts/Yoga-6-13ARE05
HOST=$(tr ' ' '-' < /sys/class/dmi/id/product_version 2>/dev/null)

LOGDIR=/var/log/dotfiles-setup
LOG="$LOGDIR/$(date '+%Y-%m-%d_%H%M%S').log"
mkdir -p "$LOGDIR"
exec > >(tee -a "$LOG") 2>&1

PACKAGES=(
    # Desktop
    pipewire-audio pipewire-pulse wireplumber pavucontrol swaync hyprlock hypridle
    hyprshot hyprpicker hyprpolkitagent polkit lxappearance blueman impala udiskie
    cliphist wl-clipboard brightnessctl tlp
    # Chinese input
    fcitx5-im fcitx5-rime fcitx5-chinese-addons fcitx5-pinyin-zhwiki fcitx5-configtool
    # Apps
    thunar yazi fastfetch gnome-text-editor gnome-keyring keepassxc thunderbird
    libreoffice-still kid3 vlc-plugin-dvb btop htop
    # Command line tools (several are yazi previewers)
    unzip 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick ffmpeg
    # Phones and drives
    libimobiledevice usbmuxd ifuse ntfs-3g exfatprogs
    # Security and updates
    ufw rkhunter arch-audit pacman-contrib
    # Fonts. Waybar icons are SVGs in the repo, so the bar needs no icon font;
    # ttf-nerd-fonts-symbols is for yazi
    gnome-themes-extra ttf-jetbrains-mono ttf-nerd-fonts-symbols
    adobe-source-han-sans-cn-fonts ttf-dejavu gnu-free-fonts noto-fonts
)

# Replaced by the fonts above. The AR PL fonts put Chinese characters where the
# waybar icons used to be.
OLD_PACKAGES=(ttf-arphic-ukai ttf-arphic-uming ttf-fira-code woff2-font-awesome)

FAILED=()

# step <description> <function>: run one step, log the result, record failures
step() {
    echo
    echo "=== [$(date +%T)] $1"
    if "$2"; then
        echo "--- OK: $1"
    else
        echo "!!! FAILED: $1 (see above, or search the log for '$1')"
        FAILED+=("$1")
        return 1
    fi
}

enable_multilib() {
    # Steam needs 32-bit libraries from the multilib repo, which is commented
    # out in a fresh /etc/pacman.conf. Runs before the update so it gets synced.
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        echo "multilib is already enabled"
        return 0
    fi
    if ! grep -q '^#\[multilib\]' /etc/pacman.conf; then
        echo "No [multilib] section in /etc/pacman.conf to enable"
        return 1
    fi
    cp /etc/pacman.conf "/etc/pacman.conf.bak-$(date '+%Y-%m-%d_%H%M%S')"
    # Uncomment "#[multilib]" and the "#Include" line after it
    sed -i '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
    grep -A1 '^\[multilib\]' /etc/pacman.conf
}

update_system() {
    pacman -Syu
}

install_steam() {
    # Steam depends on "a" 32-bit Vulkan driver, and --noconfirm would pick
    # the first provider whatever the GPU, so install the matching one first
    local drivers=()
    local vendor
    for vendor in $(cat /sys/class/drm/card*/device/vendor 2>/dev/null | sort -u); do
        case $vendor in
            0x1002) drivers+=(vulkan-radeon lib32-vulkan-radeon) ;;
            0x8086) drivers+=(vulkan-intel lib32-vulkan-intel) ;;
            0x10de)
                echo "NVIDIA GPU: install its driver (see wiki.archlinux.org/title/NVIDIA), then run setup.sh again"
                return 1
                ;;
        esac
    done
    if [ ${#drivers[@]} -eq 0 ]; then
        echo "Couldn't identify the GPU, so not choosing a Vulkan driver for Steam"
        return 1
    fi
    pacman -S --needed --noconfirm lib32-mesa "${drivers[@]}" steam
}

install_packages() {
    pacman -S --needed --noconfirm "${PACKAGES[@]}" && return 0

    # One bad name fails the whole transaction, so retry one at a time to
    # install the rest and report exactly which ones failed
    echo "Installing all at once failed; retrying one package at a time"
    local missing=()
    for p in "${PACKAGES[@]}"; do
        pacman -S --needed --noconfirm "$p" > /dev/null 2>&1 || missing+=("$p")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "These packages failed to install: ${missing[*]}"
        echo "Check the names with: pacman -Ss <name>"
        return 1
    fi
}

remove_old_packages() {
    # Only once the replacement Chinese font is in, or Chinese text breaks
    if ! pacman -Q adobe-source-han-sans-cn-fonts > /dev/null 2>&1; then
        echo "adobe-source-han-sans-cn-fonts isn't installed, keeping the old fonts"
        return 1
    fi
    local installed=()
    for p in "${OLD_PACKAGES[@]}"; do
        pacman -Q "$p" > /dev/null 2>&1 && installed+=("$p")
    done
    if [ ${#installed[@]} -eq 0 ]; then
        echo "Nothing to remove"
        return 0
    fi
    pacman -Rs --noconfirm "${installed[@]}"
}

link_configs() {
    chmod 755 ./.config/hypr/toggle_layout.sh ./link.sh ./usr/local/bin/* ./setup/*.sh
    # As the user, so they own the links
    sudo -H -u "$USER_NAME" ./link.sh
}

copy_system_files() {
    # Generic files first, then this machine's (e.g. tlp.conf, udev rules)
    cp -rv ./usr/. /usr/ && cp -rv ./etc/. /etc/ || return 1
    if [ -n "$HOST" ] && [ -d "./hosts/$HOST/etc" ]; then
        cp -rv "./hosts/$HOST/etc/." /etc/ || return 1
    else
        echo "No hosts/$HOST/etc, only generic system files copied"
    fi
    udevadm control --reload && udevadm trigger -s power_supply
}

enable_services() {
    systemctl daemon-reload &&
        systemctl enable --now tlp pacman-download.timer paccache.timer security-scan.timer
}

enable_user_services() {
    local uid
    uid=$(id -u "$USER_NAME")
    if [ -d "/run/user/$uid" ]; then
        sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload &&
            sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$uid" \
                systemctl --user enable --now pacman-updates-notify.path security-scan-notify.path
    else
        # Not logged in, so no user manager to talk to: enable by hand
        local wants="$USER_HOME/.config/systemd/user/default.target.wants"
        sudo -u "$USER_NAME" mkdir -p "$wants" &&
            sudo -u "$USER_NAME" ln -sf ../pacman-updates-notify.path ../security-scan-notify.path "$wants/"
    fi
}

setup_hibernation() {
    ./setup/hibernate.sh
}

setup_firewall() {
    # iptables.service would load its own ruleset at boot, replacing ufw's
    if systemctl is-enabled -q iptables 2> /dev/null; then
        systemctl disable --now iptables || return 1
    fi
    ufw default deny incoming &&
        ufw default allow outgoing &&
        ufw --force enable &&
        systemctl enable ufw   # without this the rules aren't loaded at boot
}

setup_ssh() {
    if ! pacman -Q openssh > /dev/null 2>&1; then
        echo "openssh isn't installed, skipping"
        return 0
    fi
    if ! grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config; then
        echo "/etc/ssh/sshd_config doesn't include sshd_config.d/, so the settings would be ignored"
        return 1
    fi

    # Older versions of this script appended AllowUsers to sshd_config on every
    # run (sometimes as root); the drop-in below replaces them
    if grep -q '^AllowUsers ' /etc/ssh/sshd_config; then
        cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak-$(date '+%Y-%m-%d_%H%M%S')"
        sed -i '/^AllowUsers /d' /etc/ssh/sshd_config
        echo "Removed old AllowUsers lines from /etc/ssh/sshd_config (backed up)"
    fi

    cat > /etc/ssh/sshd_config.d/10-dotfiles.conf <<EOF
# Written by setup.sh in the dotfiles repo
PermitRootLogin no
PasswordAuthentication no
AllowUsers $USER_NAME
EOF
    sshd -t || return 1
    if systemctl is-active -q sshd; then
        systemctl reload sshd
    fi
}

rootkit_check() {
    # The first run records what the system files look like now
    if [ ! -s /var/lib/rkhunter/db/rkhunter.dat ]; then
        rkhunter --propupd
    fi
    # --sk: don't wait for keypresses; --rwo: only print warnings
    if ! rkhunter --check --sk --rwo; then
        echo "rkhunter found warnings, details in /var/log/rkhunter.log"
        echo "After an update, warnings about changed files are expected: check them, then run 'sudo rkhunter --propupd'"
        return 1
    fi
}

echo "dotfiles setup for $USER_NAME on '${HOST:-unknown model}', log: $LOG"

step "Enable multilib (for Steam)" enable_multilib

# Installing on top of a failed update would be a partial upgrade, so stop here
if ! step "Update the system" update_system; then
    echo
    echo "Stopping: fix the update first (see docs/pacman-download-failures.md). Log: $LOG"
    exit 1
fi
step "Install packages" install_packages
step "Install Steam" install_steam
step "Remove replaced packages" remove_old_packages
step "Link user configs" link_configs
step "Copy system files" copy_system_files &&
    step "Enable system services" enable_services
step "Enable user services" enable_user_services
step "Set up hibernation" setup_hibernation
step "Firewall" setup_firewall
step "SSH" setup_ssh
step "Rootkit check" rootkit_check

echo
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "=== All steps succeeded. Log: $LOG"
else
    echo "=== ${#FAILED[@]} step(s) failed:"
    printf '  - %s\n' "${FAILED[@]}"
    echo "Fix them and run setup.sh again; finished steps are skipped or harmless to repeat."
    echo "Log: $LOG"
    exit 1
fi
