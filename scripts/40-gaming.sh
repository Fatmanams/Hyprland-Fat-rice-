#!/usr/bin/env bash
# 40-gaming.sh — gaming extras (per your "optional, low cost to include"
# note). All from official repos, no AUR.
#
# These will already have been installed by 00-base.sh, so this script
# is mostly about wiring them up correctly, not just installing them.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user."
    exit 1
fi

echo "==> [1/3] Verifying gaming packages"
sudo pacman -S --needed --noconfirm \
    gamemode gamescope mangohud lib32-mangohud

echo "==> [2/3] Enabling gamemoded (user systemd unit)"
systemctl --user enable --now gamemoded.service 2>/dev/null || \
    systemctl --user enable gamemoded.service 2>/dev/null || \
    echo "    gamemoded could not be enabled as user unit — try 'systemctl --user start gamemoded' yourself."

echo "==> [3/3] Suggested Steam Launch Options (for Minecraft / Cities: Skylines)"
cat <<'EOF'
  Minecraft (PrismLauncher / MultiMC):
     prismlauncher -- gamemoderun %command%
      (no mangohud needed — use the JVM in-game F3 to see FPS; or
       for HUD: prismlauncher -- gamemoderun mangohud %command%)

  Cities: Skylines (Steam/Proton):
      gamemoderun mangohud %command%
  For fullscreen-upscaled-HDR-Vulkan rendering on Cities:
      gamescope -W 2560 -H 1440 -r 144 -f -- gamemoderun mangohud %command%
EOF

echo
echo "==> mangohud config: ~/.config/MangoHud/MangoHud.conf"
echo "    (already installed by 30-dotfiles.sh's blanket cp of config/.)"
echo "    Default preset: fps,cpu_stats,gpu_stats,ram,vram,frame_timing,histogram"
echo "    Toggle HUD in-game with Right Shift, reload cfg with Right Ctrl."
echo "==> DONE."
