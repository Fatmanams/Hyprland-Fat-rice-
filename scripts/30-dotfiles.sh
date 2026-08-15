#!/usr/bin/env bash
# 30-dotfiles.sh — install the rice's dotfile tree from this repo into ~/.config.
#
# No clobbering without backup. Existing files get moved into
# ~/.config-backup/<TS>/ first, then the new configs layered on.
#
# Doesn't run any daemons — just lays files down. After this, see the
# README for the post-install session-start procedure.
#
# ADDING A NEW COMPONENT (maintenance checklist):
#   1. Drop its dotfiles under config/<component>/ in this repo — the
#      blanket `cp -a` below picks it up automatically, no script edit
#      needed for the plain case.
#   2. If the dir does NOT belong under ~/.config/ (like
#      config/applications/), add a carve-out rm -rf below.
#   3. If the files contain placeholders (@HOME@ pattern) or need a
#      binary present to be useful (emacs pattern), add the post-copy
#      step below and keep it idempotent — this script gets re-run.
#   4. Wire it into hyprland.conf (exec-once / bind) and document it in
#      README.md + AGENTS.md.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user."
    exit 1
fi

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
CFG_SRC="$REPO_ROOT/config"
TS=$(date +%Y%m%d-%H%M%S)
BAK="$HOME/.config-backup-$TS"

if [[ ! -d "$CFG_SRC" ]]; then
    echo "Expected $CFG_SRC to exist — was README not followed?"
    exit 1
fi

echo "==> Backing up current ~/.config to $BAK"
mkdir -p "$BAK"
if [[ -d "$HOME/.config" ]]; then
    cp -a "$HOME/.config/." "$BAK/"
fi

echo "==> Copying rice configs into ~/.config"
# Make target dirs as needed, one per top-level component.
mkdir -p "$HOME/.config"
cp -a "$CFG_SRC/." "$HOME/.config/"

# config/applications/ only exists as the source for the .desktop install
# below — it does NOT belong under ~/.config/ (nothing reads
# ~/.config/applications/). Remove the stray copy the blanket cp made;
# the real copy lands in ~/.local/share/applications/. Anything removed
# here is recoverable from the $BAK backup taken above.
rm -rf "$HOME/.config/applications"

# config/emacs/ only matters if emacs was opted into in 00-base.sh; drop
# the stray copy otherwise (recoverable from the backup above). Emacs
# reads ~/.config/emacs/init.el only when ~/.emacs.d does not exist.
if ! command -v emacs >/dev/null 2>&1; then
    rm -rf "$HOME/.config/emacs"
fi

# Hyprland's `source = ~/.config/hypr/keybinds-extra.conf` line cannot
# take shell redirects, so the file MUST exist for the compositor to load
# the main config without error. cp -a above covers this from the repo's
# config/hypr/keybinds-extra.conf, but defensively touch it here too in
# case the repo file was deleted after install:
mkdir -p "$HOME/.config/hypr"
touch "$HOME/.config/hypr/keybinds-extra.conf"

# The rice ships a zed-handler.desktop file under config/applications/.
# (~/.local/share/applications/). Also refresh the desktop database so
# the file is picked up immediately by xdg-mime and rofi.
echo "==> Installing zed-handler.desktop into ~/.local/share/applications/"
mkdir -p "$HOME/.local/share/applications"
cp -f "$CFG_SRC/applications/zed-handler.desktop" "$HOME/.local/share/applications/" 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || \
    echo "    (update-desktop-database not available — install desktop-file-utils)"

# config/vlc/vlcrc ships snapshot-path with an @HOME@ placeholder: VLC
# does no tilde expansion on that option (see the vlcrc comments), so
# expand it here and pre-create the dir (VLC won't create it itself).
# Idempotent: on re-run the placeholder is already gone.
sed -i "s|@HOME@|$HOME|g" "$HOME/.config/vlc/vlcrc"
mkdir -p "$HOME/Pictures/vlc-snapshots"

# A couple of paths need to be created/written by tooling on first run;
# make them now so nothing errors out.
mkdir -p "$HOME/.cache/wal"

echo "==> Generating first pywal palette from wallpaper (if set)"
WALLPAPER="$HOME/.config/hypr/wallpaper.jpg"
if [[ -f "$WALLPAPER" ]]; then
    wal -i "$WALLPAPER" -q
    echo "    wal ran. colors at ~/.cache/wal/colors.sh"
else
    echo "    no wallpaper at $WALLPAPER — hypr/wallpaper.jpg is a TODO."
    echo "    drop a jpg there and run: wal -i ~/.config/hypr/wallpaper.jpg"
fi

echo
echo "==> Next steps:"
echo "      1. Edit ~/.config/hypr/hyprland.conf  -> set monitor= from 'hyprctl monitors'"
echo "      2. Drop a wallpaper at ~/.config/hypr/wallpaper.jpg"
echo "      3. Re-login -> pick Hyprland in SDDM"
echo "      4. ./40-gaming.sh for gaming extras (if not already run)"
echo "==> DONE"
