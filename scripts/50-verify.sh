#!/usr/bin/env bash
# 50-verify.sh — read-only post-deploy health check.
#
# This script reports, it never fixes. No auto-editing of configs, no
# auto-enabling of services — a FAIL here means "go fix it by hand".
#
# Run AFTER 00–40 have completed and at least one Hyprland session has
# been booted. Some checks read installed system state (pacman,
# systemctl, ufw); only the theme-preset check runs against this repo
# checkout by design.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user."
    exit 1
fi

FAILS=0

pass() { echo "    PASS: $1"; }
fail() { echo "    FAIL: $1"; FAILS=$((FAILS + 1)); }

HYPR_CFG="$HOME/.config/hypr"

echo "==> [1/7] First-boot TODOs cleared"
# hyprland.conf / hyprpaper.conf ship with literal "@@ TODO @@"
# placeholders (monitor name, wallpaper path) the user must replace
# after first boot. Any leftover means the stopgap is still live.
todo_hits=$(grep -Rn '@@ TODO @@' "$HYPR_CFG/hyprland.conf" "$HYPR_CFG/hyprpaper.conf" 2>/dev/null || true)
if [[ -z "$todo_hits" ]]; then
    pass "no '@@ TODO @@' placeholders remain in installed hypr configs"
else
    fail "unresolved '@@ TODO @@' placeholders:"
    echo "$todo_hits" | sed 's/^/        /'
fi

echo "==> [2/7] GPU driver sanity"
# Same lspci detection 00-base.sh used at install time; cross-checked
# against installed packages so a half-finished driver swap is caught.
gpu_line=$(lspci -nn | grep -Ei ' VGA compatible controller: ' || true)
if [[ -z "$gpu_line" ]]; then
    fail "no VGA controller detected by lspci"
else
    echo "    detected: $gpu_line"
    if echo "$gpu_line" | grep -qi nvidia; then
        if pacman -Qi nvidia &>/dev/null; then
            pass "NVIDIA GPU detected and nvidia package installed"
        else
            fail "NVIDIA GPU detected but nvidia package not installed"
        fi
    else
        if pacman -Qi mesa &>/dev/null; then
            pass "Intel/AMD GPU detected and mesa installed"
        else
            fail "Intel/AMD GPU detected but mesa not installed"
        fi
    fi
fi

echo "==> [3/7] ufw firewall"
# Both halves matter: the unit can be "active" while ufw itself was
# never enabled, and vice versa.
if systemctl is-active --quiet ufw.service && ufw status 2>/dev/null | grep -q "Status: active"; then
    pass "ufw.service active and ufw reports Status: active"
else
    fail "ufw not fully active (unit: $(systemctl is-active ufw.service 2>&1), ufw status: $(ufw status 2>/dev/null | head -n1 || echo 'unreadable'))"
fi

echo "==> [4/7] clamav-freshclam"
if systemctl is-active --quiet clamav-freshclam.service; then
    pass "clamav-freshclam.service active"
else
    fail "clamav-freshclam.service not active (state: $(systemctl is-active clamav-freshclam.service 2>&1))"
fi

echo "==> [5/7] bluetooth"
if systemctl is-active --quiet bluetooth.service; then
    pass "bluetooth.service active"
else
    fail "bluetooth.service not active (state: $(systemctl is-active bluetooth.service 2>&1))"
fi

echo "==> [6/7] SDDM rollback snapshot exists"
# 20-sddm.sh snapshots /etc/sddm.conf.d + /usr/share/sddm/themes into
# /root/sddm-snap.<TS>/ before touching anything. /root is unreadable
# to a normal user, so without sudo we can only say "cannot check"
# rather than guess — rerun with sudo to verify properly.
if sudo -n true 2>/dev/null; then
    if sudo -n sh -c 'compgen -G "/root/sddm-snap.*" >/dev/null'; then
        pass "at least one /root/sddm-snap.* snapshot exists"
    else
        fail "no /root/sddm-snap.* snapshot found (20-sddm.sh may not have run)"
    fi
else
    echo "    SKIP: cannot check /root without root — run with sudo to verify (not counted as FAIL)"
fi

echo "==> [7/7] Theme preset integrity (repo checkout)"
# Same logic as .github/workflows/lint.yml's "theme presets carry every
# pywal format" step: each preset dir must ship all five formats, and
# switch-theme.sh must reference each one — a format missing from
# either place leaves that consumer on a stale palette after a switch.
# This one intentionally runs against the repo checkout, not ~/, so it
# can catch a bad commit before it ever reaches the installed system.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMATS=(colors-waybar.css colors-rofi.rasi colors-wal.vim colors.el colors.sh)
theme_ok=1
for d in "$REPO_ROOT"/config/hypr/themes/*/; do
    for f in "${FORMATS[@]}"; do
        if [[ ! -f "$d$f" ]]; then
            echo "    MISSING: $d$f"
            theme_ok=0
        fi
    done
done
for f in "${FORMATS[@]}"; do
    if ! grep -q "$f" "$REPO_ROOT/config/hypr/switch-theme.sh"; then
        echo "    MISSING from switch-theme.sh cp list: $f"
        theme_ok=0
    fi
done
if [[ $theme_ok -eq 1 ]]; then
    pass "all presets carry all 5 pywal formats and switch-theme.sh lists them"
else
    fail "theme preset integrity broken (see MISSING lines above)"
fi

echo
echo "==> SUMMARY: $FAILS check(s) failed"
if [[ $FAILS -eq 0 ]]; then
    echo "==> DONE (all checks passed)."
    exit 0
else
    echo "==> DONE (fix the FAILs above by hand — this script never auto-fixes)."
    exit 1
fi
