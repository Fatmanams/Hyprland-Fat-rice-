#!/usr/bin/env bash
# 00-base.sh — official-repo installs only. No AUR, no makepkg, no curl|bash.
#
# What this does:
#   1. Enables [multilib] (needed for lib32-mangohud / Steam's wine deps).
#   2. Sets MAKEFLAGS to -j$(nproc) and enables ccache in /etc/makepkg.conf
#      — affects AUR builds done later by 10-aur.sh.
#   3. Installs the official-repo portion of the rice from pacman.
#
# Run this as a normal user (it will sudo internally where needed).
# Review it before running. Nothing is silent.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Don't run this as root. Run as your normal user; it'll sudo where needed."
    exit 1
fi

echo "==> [1/3] Enabling [multilib] in /etc/pacman.conf"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
    echo "    multilib enabled."
else
    echo "    multilib already enabled."
fi
sudo pacman -Sy

echo "==> [2/3] Configuring /etc/makepkg.conf for parallelism + ccache"
MAKEPKG=/etc/makepkg.conf
if ! grep -q '^MAKEFLAGS="-j' "$MAKEPKG"; then
    sudo sed -i "s|^#MAKEFLAGS=\"-j2\"|MAKEFLAGS=\"-j$(nproc)\"|" "$MAKEPKG"
    echo "    MAKEFLAGS set to -j$(nproc)"
else
    echo "    MAKEFLAGS already set."
fi
if ! command -v ccache >/dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed ccache
fi
if ! grep -q '!ccache' "$MAKEPKG"; then
    sudo sed -i 's|^BUILDENV=.*|BUILDENV=(!distcc !color !ccache check !sign)|' "$MAKEPKG"
    echo "    ccache enabled in BUILDENV"
else
    echo "    ccache already in BUILDENV"
fi

echo "==> [3/3] Installing rice packages from official repos"
sudo pacman -S --needed --noconfirm \
    hyprland hypridle hyprlock hyprcursor hyprpaper hyprutils hyprlang \
    wayland wayland-protocols \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    xdg-utils file \
    qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6ct qt5ct \
    sddm \
    rofi-wayland \
    swaync \
    swayidle swaybg sway \
    waybar wob kanshi \
    dunst \
    grim slurp wl-clipboard \
    wlsunset \
    ghostty kitty alacritty \
    nano \
    polkit polkit-gnome polkit-kde-agent gnome-keyring seahorse \
    NetworkManager \
    pipewire wireplumber \
    noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-liberation ttf-dejavu \
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols \
    fontconfig \
    jq curl wget git base-devel \
    gcc clang make cmake meson ninja pkgconf \
    imagemagick ffmpeg \
    hicolor-icon-theme adwaita-icon-theme sound-theme-freedesktop \
    gamemode gamescope mangohud lib32-mangohud \
    nwg-look kvantum kvantum-qt5 \
    swww cliphist \
    kvantum-qt6

echo "==> DONE. Next: ./10-aur.sh"
