#!/usr/bin/env bash
# 00-base.sh — official-repo installs only. No AUR, no makepkg, no curl|bash.
#
# What this does:
#   1. Enables [multilib] (needed for lib32-mangohud / Steam's wine deps).
#   2. Sets MAKEFLAGS to -j$(nproc) and enables ccache in /etc/makepkg.conf
#      — affects AUR builds done later by 10-aur.sh.
#   3. Installs the official-repo portion of the rice from pacman
#      (labeled groups below — add new packages to the matching group).
#   4. Post-install: xdg user dirs, bluetooth.service, ufw baseline.
#   5. OPTIONAL emacs prompt (default: skip).
#   6. GPU driver layer — NVIDIA proprietary or Intel/AMD Mesa, one or
#      the other, picked from lspci detection with confirmation.
#
# Run this as a normal user (it will sudo internally where needed).
# Review it before running. Nothing is silent.
#
# Idempotent: pacman --needed skips installed packages, the sed edits are
# grep-guarded, so re-running is safe (the prompts still appear).

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
sudo pacman -Syu --noconfirm

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
# The list is split into labeled groups so a new package lands somewhere
# obvious. When extending, keep these rules:
#   - official repos ONLY (policy rule #1); AUR-only packages belong in
#     10-aur.sh's PACKAGES array instead
#   - after any add/remove, update the rule-5 audit table in README.md
#     and the package notes in AGENTS.md
#   - don't merge the groups back into one transaction; the labels are
#     the maintenance map (bash can't put comments inside \-continued
#     lines, which is why each group is its own pacman call)

# Hyprland core + Wayland plumbing (compositor, lock/idle, portals).
sudo pacman -S --needed --noconfirm \
    hyprland hypridle hyprlock hyprcursor hyprpaper hyprutils hyprlang \
    wayland wayland-protocols \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

# XDG helpers + Qt runtime/theme bits. Qt apps run Wayland via
# QT_QPA_PLATFORM set in hyprland.conf; qt6ct/qt5ct pick their themes.
sudo pacman -S --needed --noconfirm \
    xdg-utils xdg-user-dirs file \
    qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6ct qt5ct

# Login manager, launcher, bar, notifications, screenshot/clipboard,
# night light.
sudo pacman -S --needed --noconfirm \
    sddm \
    rofi-wayland \
    swaync \
    waybar kanshi \
    grim slurp wl-clipboard \
    wlsunset

# Terminals + shell. ghostty is the primary terminal (see its config);
# kitty/alacritty ship as alternates.
sudo pacman -S --needed --noconfirm ghostty kitty alacritty fish

# Editors. nano exists purely as the sudoedit/visudo fallback (see the
# README "Sudoedit / visudo gotcha"); neovim is the terminal editor.
sudo pacman -S --needed --noconfirm nano neovim

# Session plumbing: polkit auth agents, keyring, network, audio.
sudo pacman -S --needed --noconfirm \
    polkit polkit-gnome polkit-kde-agent gnome-keyring seahorse \
    NetworkManager \
    pipewire wireplumber

# Fonts. ttf-jetbrains-mono-nerd is the mono used by ghostty/nvim/zed.
sudo pacman -S --needed --noconfirm \
    noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-liberation ttf-dejavu \
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols \
    fontconfig

# Toolchain + everyday CLI tools (base-devel & friends are also needed
# by the AUR builds in 10-aur.sh).
sudo pacman -S --needed --noconfirm \
    jq curl wget git base-devel \
    gcc clang make cmake meson ninja pkgconf \
    ripgrep fd zoxide chafa \
    poppler \
    imagemagick ffmpeg \
    pciutils mesa-demos

# Icon/sound themes + GTK/Qt theming GUIs (nwg-look = GTK, kvantum = Qt).
sudo pacman -S --needed --noconfirm \
    hicolor-icon-theme adwaita-icon-theme papirus-icon-theme sound-theme-freedesktop \
    nwg-look kvantum kvantum-qt5

# Gaming stack (gamemoded user unit is wired by 40-gaming.sh).
sudo pacman -S --needed --noconfirm \
    gamemode gamescope mangohud lib32-mangohud steam

# Wallpaper daemon for static images (mpvpaper, the animated-wallpaper
# default, is AUR — see 10-aur.sh) + clipboard history manager.
sudo pacman -S --needed --noconfirm swww cliphist

# File managers: yazi (TUI) + thunar (GUI) with thumbnails/archives/
# volume mounting support.
sudo pacman -S --needed --noconfirm \
    yazi thunar tumbler thunar-archive-plugin thunar-volman gvfs

# Apps: media player, password manager (SUPER+V bind), kde-cli-tools
# (kdialog etc. for Qt apps running outside Plasma).
sudo pacman -S --needed --noconfirm vlc bitwarden kde-cli-tools

# Bluetooth stack + tray applet (blueman-applet autostarts from
# hyprland.conf; service enabled in [3.1/4] below).
sudo pacman -S --needed --noconfirm bluez bluez-utils blueman

# Firewall (baseline rules set up in [3.1/4] below).
sudo pacman -S --needed --noconfirm ufw

echo "==> [3.1/4] Post-install setup: user dirs, Bluetooth, firewall"
xdg-user-dirs-update
echo "    xdg user dirs created/updated (~/Pictures, ~/Downloads, ...)."

sudo systemctl enable --now bluetooth.service
echo "    bluetooth.service enabled."

# Default-deny incoming / allow outgoing baseline for a personal desktop.
# NOTE: hosting game servers or LAN services (e.g. a Minecraft server)
# will need explicit `sudo ufw allow <port>` rules added later.
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
# ufw --force enable only starts it for THIS boot; on Arch the firewall
# comes back after reboot only if ufw.service is enabled (ArchWiki).
sudo systemctl enable --now ufw.service
echo "    ufw active and enabled at boot: deny incoming, allow outgoing."

echo "==> [3.2/4] Optional: Emacs"
# Emacs is OFF by default — the rice's editors are Zed (GUI) and nvim
# (terminal). Opt in here if you also want Emacs; its config ships at
# config/emacs/init.el and 30-dotfiles.sh seeds it only when installed.
read -r -p "    Install emacs (official extra repo, pgtk/Wayland build)? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed --noconfirm emacs
    echo "    emacs installed."
else
    echo "    skipped emacs."
fi

echo "==> [3.5/4] GPU driver layer (NVIDIA or Intel/AMD — pick one)"
GPU_CHOSEN=0
CURRENT_GPU=$(lspci -nn 2>/dev/null | grep -Ei ' VGA compatible controller: ' | head -n1)
echo "    Detected GPU line: ${CURRENT_GPU:-unknown}"

if echo "$CURRENT_GPU" | grep -qi 'nvidia'; then
    echo "    Looks NVIDIA. Will install: nvidia nvidia-utils lib32-nvidia-utils"
    echo "    (If that's wrong, Ctrl-C now, then re-run and pick manually.)"
    read -r -p "    Proceed with NVIDIA drivers? [Y/n] " yn
    if [[ "$yn" =~ ^[Nn]$ ]]; then
        GPU_CHOSEN=0
    else
        sudo pacman -S --needed --noconfirm nvidia nvidia-utils
        sudo pacman -S --needed --noconfirm --overwrite '/usr/lib32/libGL*' lib32-nvidia-utils
        GPU_CHOSEN=1
        echo "    NVIDIA installed. Make sure kernel cmdline has:"
        echo "      nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
        echo "    (grub: /etc/default/grub -> GRUB_CMDLINE_LINUX_DEFAULT -> update-grub; systemd-boot: /etc/kernel/cmdline -> reinstall linux-lts)"
    fi
fi

if [[ $GPU_CHOSEN -eq 0 ]]; then
    echo "    Installing Intel/AMD open stack (works on both):"
    sudo pacman -S --needed --noconfirm \
        mesa lib32-mesa \
        vulkan-radeon lib32-vulkan-radeon \
        vulkan-intel lib32-vulkan-intel \
        intel-media-driver libva-mesa-driver mesa-vdpau \
        vulkan-mesa-layers lib32-vulkan-mesa-layers
fi

echo "==> DONE. Next: ./10-aur.sh"
