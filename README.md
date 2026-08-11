# linux-rice

A personal Hyprland rice for a single-monitor AMD/Intel Arch Linux box.
Install is staged into reviewable scripts; AUR-only packages go through
PKGBUILD review → plain `makepkg` → `repo-add` → install from local repo
exactly. No AUR helpers (paru/yay), no `curl | bash` installers.

---

## What's in this rice

| Component        | Tool                 | Source                  | Notes |
|------------------|----------------------|-------------------------|-------|
| Compositor       | Hyprland             | pacman (extra)          |       |
| Status bar       | waybar               | pacman (extra)          |       |
| Notifications    | swaync               | pacman (extra)          | control-center + popup |
| Launcher         | rofi-wayland        | pacman (extra)          | was AUR-only, moved upstream |
| Wallpaper        | swww                 | pacman (extra)          | was AUR-only, moved upstream |
| Wall daemon      | hyprpaper            | pacman (extra)          |       |
| Clipboard        | cliphist + wl-clipboard | pacman (extra)       |       |
| Idle / lock      | hypridle + hyprlock  | pacman (extra)          |       |
| Color theming    | python-pywal16       | **AUR — makepkg'd**     |       |
| Widgets          | eww                  | **AUR — makepkg'd**     | tiny demo widget alongside waybar |
| Cursor theme     | bibata-cursor-theme  | **AUR — makepkg'd**     | Modern variant, 24px |
| Logout menu      | wlogout              | **AUR — makepkg'd**     |       |
| Terminal         | ghostty              | pacman (extra)          |       |
| Code editor      | zed                  | **AUR — makepkg'd**     | primary $EDITOR + $CODE for python/c/c++/lua/java/rust/json |
| Quick editor     | neovim              | pacman (extra)          | terminal edits, pywal-driven, no plugins |
| Display manager  | sddm                 | pacman (extra)          |       |
| SDDM theme       | sddm-astronaut-theme | **bare git clone**      | rule #4: no build step, cloned straight into /usr/share/sddm/themes |
| GTK theming GUI  | nwg-look             | pacman (extra)          |       |
| Qt theming       | kvantum / kvantum-qt5 | pacman (extra)         |       |
| Gaming           | gamemode mangohud lib32-mangohud | pacman (extra/multilib) |       |

---

## AUR-only packages — full up-front audit (policy rule #5)

These are the **only** packages built from AUR. Anything else is in
official Arch repos and installed by `scripts/00-base.sh`.

| Package                | AUR URL                                  | Build notes                                                      |
|------------------------|------------------------------------------|------------------------------------------------------------------|
| `eww`                  | `<https://aur.archlinux.org/eww.git>`    | Rust build, fetches crates from crates.io                         |
| `python-pywal16`       | `<https://aur.archlinux.org/python-pywal16.git>` | Python package, active fork of pywal              |
| `bibata-cursor-theme`  | `<https://aur.archlinux.org/bibata-cursor-theme.git>` | Cursor theme, has install hooks (systemctl-like) |
| `wlogout`              | `<https://aur.archlinux.org/wlogout.git>` | Wayland logout menu, GTK3                                         |
| `zed`                  | `<https://aur.archlinux.org/zed.git>`    | **Reviews carefully**: large Rust project, many cargo crates, may pull release assets during build |

**Packages you originally listed as AUR-only that are now in official
repos** — these are installed by `scripts/00-base.sh`, **not** built:

- `rofi-wayland` — in `extra`
- `ghostty` — in `extra`
- `swww` — in `extra`
- `swaync` — in `extra`
- `cliphist` — in `extra`
- `nwg-look` — in `extra`
- `kvantum` and `kvantum-qt5` — in `extra`
- `gamemode`, `gamescope`, `mangohud`, `lib32-mangohud` — in `extra` + `multilib`

> The policy is "use AUR for whatever has no official-repo equivalent."
> When the AUR-only list you used to need folds into upstream Arch repos,
> we stop building that thing from AUR and start using `pacman -S`.

---

## GPU compatibility (NVIDIA + Intel + AMD, same config)

The rice ships **one** `hyprland.conf` that works on either vendor with
a single commented/uncommented block. Default (no edits) = Intel/AMD.

### Vendor detection

`scripts/00-base.sh` runs `lspci` to detect your GPU and installs the
right driver stack with a single confirmation prompt:

- **NVIDIA**: `nvidia`, `nvidia-utils`, `lib32-nvidia-utils` from `extra`/`multilib`
- **Intel/AMD**: `mesa`, `vulkan-radeon`, `vulkan-intel`, `intel-media-driver`,
  `libva-mesa-driver`, and the multilib (lib32-) siblings. No vendor-blob packages.

Either path keeps `mesa` itself installed (libGL/GLX/EGL remains sane).

### Vendor-specific env vars

Two layers:

1. **Hyprland-compositor env** in `config/hypr/hyprland.conf` — bottom of
   the `# ---- Environment` block. NVIDIA users uncomment every line
   marked `# NVIDIA:`. Intel/AMD users leave them commented. These are
   `env =` directives parsed by the compositor at config-load time, so
   they cannot be set conditionally at runtime — pick once.

2. **App-level env** in `config/hypr/gpu-env.sh`. Source from your `.zshrc`
   or `.bashrc`:
   ```bash
   # ~/.zshrc or ~/.bashrc
   if [ -f ~/.config/hypr/gpu-env.sh ]; then
       . ~/.config/hypr/gpu-env.sh
   fi
   ```
   Auto-detects the GPU via `lspci` at shell start and exports the
   `__GL_THREADED_OPTIMIZATIONS`, `LIBVA_DRIVER_NAME`, `VDPAU_DRIVER`,
   `Mesa_*` overrides appropriate to that vendor. Games launched from
   Steam / Proton / CLI inherit these.

### NVIDIA-specific gotchas (read once if you're on NVIDIA)

1. **Kernel cmdline** — required for modeset-on-boot:
   ```
   nvidia_drm.modeset=1 nvidia_drm.fbdev=1
   ```
   For systemd-boot: edit `/etc/kernel/cmdline` (or `/boot/loader/entries/*.conf`)
   and reinstall `linux` (`sudo pacman -S linux`) so the cmdline is regenerated
   into the new EFI entry. For GRUB: edit `/etc/default/grub` -> `GRUB_CMDLINE_LINUX_DEFAULT`
   and run `grub-mkconfig -o /boot/grub/grub.cfg`.

2. **Hyprland config — uncomment the NVIDIA env block** in
   `~/.config/hypr/hyprland.conf`. The defaults shipped work on Intel/AMD;
   on NVIDIA the `WLR_NO_HARDWARE_CURSORS=1` line is the difference between
   a glitchy or invisible cursor (without) and a normal one (with).

3. **Don't install `nvidia-dkms` alongside `linux`** — pick one. `nvidia`
   works with stock `linux`. Use `nvidia-dkms` only if you're on `linux-zen`,
   `linux-lts`, or a custom kernel. `00-base.sh` installs the `nvidia`
   package by default; if you're on a non-stock kernel, install `nvidia-dkms`
   yourself.

4. **Wayland + NVIDIA NVK (Vulkan)** — recent `nvidia` packages ship NVK so
   `vulkan-nvidia` from the binary blob shouldn't be installed separately;
   `nvidia-utils` covers the userland GL stack. You don't need
   `vulkan-mesa-layers` either (Mesa's layers don't help on NVIDIA).

### Before any debugging "Hyprland is laggy on NVIDIA"

1. Did you set `nvidia_drm.modeset=1` on the cmdline? Verify with
   `cat /sys/module/nvidia_drm/parameters/modeset` — must print `Y`.
2. Did you uncomment the NVIDIA env block in `hyprland.conf`?
3. Is `nvidia-dkms` matching your kernel's package? `uname -r` vs `pacman -Q linux`.
4. Restart SDDM (`sudo systemctl restart sddm`), not just Hyprland.

---



Run the staged scripts in order. **Read each one before running.** None
are silent; AUR builds explicitly pause and print the PKGBUILD for your
sign-off before building anything.

```bash
chmod +x scripts/*.sh

# 1. Official-repo install — also configures /etc/makepkg.conf with
#    MAKEFLAGS=-j$(nproc) and ccache in BUILDENV, and enables [multilib].
./scripts/00-base.sh

# 2. AUR builds — reviewed PKGBUILD, plain makepkg (build only),
#    repo-add into your local repo at /var/cache/pacman/localrepo,
#    then pacman -S from there. No AUR helpers. Pause+review each.
./scripts/10-aur.sh

# 3. SDDM theme — bare git clone per policy rule #4. Snapshots the
#    old SDDM state first, then clones Keyitdev's sddm-astronaut-theme
#    into /usr/share/sddm/themes/sddm-astronaut-theme and addresses
#    Current= in a new conf.d/10-theme.conf.
./scripts/20-sddm.sh

# 4. Dotfiles — copies config/ tree into ~/.config, with a backup of
#    existing ~/.config first. Also installs zed-handler.desktop for
#    the MIME associations defined in hyprland.conf.
./scripts/30-dotfiles.sh

# 5. Gaming extras — verifies gamemoded, prints Steam/prismlauncher
#    launch-option templates.
./scripts/40-gaming.sh
```

You can run each script at most once. Reading them first is the point.

---

## Mandatory first-boot TODOs

Before the rice looks right:

1. **Monitor name.** `hyprland.conf` ships with:
   ```
   monitor=,preferred,auto,1
   ```
   Auto-detect is a **stopgap** per the upstream gotcha note. After your
   first boot, run:
   ```
   hyprctl monitors
   ```
   and **edit `~/.config/hypr/hyprland.conf`'s monitor= line** with the
   actual monitor name, mode, and refresh rate. Example for a 1440p/144Hz
   DisplayPort display:
   ```
   monitor=DP-1, 2560x1440@144, 0x0, 1
   ```

2. **Wallpaper.** Drop a JPG at `~/.config/hypr/wallpaper.jpg`. This is
   the path read by both `hyprpaper.conf`'s preload= AND the `wal -i`
   exec-once in `hyprland.conf` — keeping them in sync means changing
   the wallpaper is one command. Once dropped:
   ```
   wal -i ~/.config/hypr/wallpaper.jpg
   ```
   That regenerates `~/.cache/wal/colors.css`, which waybar / swaync /
   rofi / eww all `@import` for their color palette.

3. **Same edit in `~/.config/hypr/hyprpaper.conf`** — set the
   `wallpaper = <monitor>, ~/.config/hypr/wallpaper.jpg` line's monitor
   name to match `hyprctl monitors`.

---

## Rolling back if SDDM crashes

SDDM is the riskiest single piece because a broken QML greeter can
land you at a black screen with no obvious way back into X or a tty.
This rice keeps:

- the KDE/Plasma session entry installed and selectable the whole
  time (so if Hyprland or the greeter itself breaks you can still log
  in to a Plasma session via SDDM's drop-down)
- a snapshot of the old `/etc/sddm.conf.d` + `/usr/share/sddm/themes`
  in `/root/sddm-snap.<TIMESTAMP>/` (created by `20-sddm.sh`)
- the previously working `Current=` value saved as
  `/root/sddm-snap.<TIMESTAMP>/PREVIOUS_Current.txt`

**If SDDM renders black** after running `20-sddm.sh`:

```bash
# 1. Switch to a TTY:
#    Ctrl + Alt + F3       (F1 or F2 is the greeter, may be black)

# 2. As root:
sudo systemctl stop sddm

# 3. Revert the conf.d drop-in that points Current= at the new theme:
sudo rm /etc/sddm.conf.d/10-theme.conf
#    Or, to fully roll back from the snapshot:
#    sudo cp -a /root/sddm-snap.<TS>/sddm.conf.d/. /etc/sddm.conf.d/
#    sudo cp -a /root/sddm-snap.<TS>/themes/.        /usr/share/sddm/themes/

# 4. Bring SDDM back:
sudo systemctl start sddm
```

If the issue persists, hold `Shift` while booting to get the SDDM
session picker, choose **Plasma** instead of Hyprland, and you have a
working GUI to investigate from.

---

## Code editor setup (Zed, Neovim, Ghostty)

Per your ask, **Zed** is the default editor for `python`, `c`, `c++`,
`lua`, `java`, `rust`, and `json` files. `hyprland.conf` runs
`xdg-mime default` at session start against the `zed-handler.desktop`
file copied by `30-dotfiles.sh` into `~/.local/share/applications/`.
The handler also covers adjacent types (C headers, JavaScript, TOML,
YAML, markdown, shell, plaintext).

**Neovim** is configured at `~/.config/nvim/init.lua` — single-file,
no plugin manager, pywal-driven colors (matches the rest of the rice).
Use it for terminal-side edits where you want syntax-aware highlighting
without popping a GUI window: script hacks, dockerfile edits, quick
patches. It's not your IDE — Zed is.

**Ghostty** is the primary terminal. Its config at
`~/.config/ghostty/config` bakes Catppuccin Mocha as a fallback palette
(pywal16 doesn't yet write a ghostty-compatible config file; see the
file header comment for the TODO).

Bindings:

| Keybind           | Action                                       |
|-------------------|----------------------------------------------|
| `SUPER + E`        | Open Zed                                     |
| `SUPER + SHIFT + E`| Open Thunar (was SUPER+E before Zed won it)  |

### Sudoedit / visudo gotcha

Zed is a Wayland GUI app, and `$EDITOR` is set to `zed --wait`. This works
for git commit messages (`git commit` blocks until you close the tab),
crontab (`crontab -e`), and most interactive `$EDITOR` invocations.

**It does not work cleanly from inside `sudoedit`/`visudo`** — those
run as root, and a Wayland GUI app launched from a root process won't be
able to connect to your user's wayland socket. For those specific cases,
pass an explicit editor:

```bash
sudoedit -e nano /path/to/file       # nano ships with /core
# or:
SUDO_EDITOR=nano sudoedit /path/to/file
```

`nano` is installed by `00-base.sh` specifically as this fallback. If
you'd rather have `$EDITOR` be `nano` globally and only use Zed when
explicitly invoked, edit `~/.config/hypr/hyprland.conf`'s `env = EDITOR...`
and `env = VISUAL...` lines. The `SUPER+E` bind for Zed is independent
and won't be affected.

---

## Steam / Wine / Proton launch-option recipes (gaming set)

Verify `gamemoded` is running:
```bash
systemctl --user status gamemoded
```

If not, start it once and enable for this user:
```bash
systemctl --user enable --now gamemoded.service
```

### Minecraft (PrismLauncher / MultiMC)

Best: skip the in-game profiler, use mangohud:
```
prismlauncher -- gamemoderun mangohud %command%
```

For no HUD (you'll read FPS via F3):
```
prismlauncher -- gamemoderun %command%
```

### Cities: Skylines (Steam/Proton)

```
gamemoderun mangohud %command%
```

For upscaled-Vulkan via gamescope at 1440p/144Hz:
```
gamescope -W 2560 -H 1440 -r 144 -f -- gamemoderun mangohud %command%
```

The MangoHud config at `~/.config/MangoHud/MangoHud.conf` covers FPS,
CPU/GPU stats, RAM, VRAM, swap, histogram, and is toggleable with
**Right Shift** during gameplay.

---

## Package policy (kept reference-only here so the rules are visible)

1. **Official repos first.** If it's in `pacman -S`, that's where it comes from.
2. **No AUR helpers** (paru/yay). **No `curl | bash` installers** anywhere,
   including upstream one-liner install scripts.
3. **AUR-only packages**: pull PKGBUILD, print it, **read it in full**
   (look for `curl | bash`, post_registration wget, suspicious source
   URLs), build with plain `makepkg` (no `-si`, build only), `repo-add`
   the resulting `.pkg.tar.zst` to a local repo, then `pacman -S` from
   that repo. `scripts/10-aur.sh` implements exactly this.
4. **Static-asset/no-build repos** (like sddm-astronaut-theme): plain
   `git clone` straight from upstream into the documented install path,
   no PKGBUILD wrapper manufactured. `scripts/20-sddm.sh` does this.
5. **All AUR-only items listed up-front** so the review/build step is
   visible before any build starts. The table at the top of this README
   is the rule-5 audit for this build.

### Build-speed tweaks (applied by `scripts/00-base.sh`)

- `/etc/makepkg.conf`:`MAKEFLAGS="-j$(nproc)"`
- `/etc/makepkg.conf`:`BUILDENV=(... ccache ...)` — `ccache` from
  official repos; pays for itself against the AUR build queue
- Local repo at `/var/cache/pacman/localrepo` (`localrepo`,
  `SigLevel = Optional TrustAll`) — `10-aur.sh` registers it
  into `/etc/pacman.conf` once if not already present

### Gotchas handled proactively

- **xdg-desktop-portal-hyprland covers screen capture only.**
  File-picker dialogs in random GTK apps will hang or fail without
  `xdg-desktop-portal-gtk` alongside it as fallback. Both are
  installed by `00-base.sh`; `hyprland.conf` explicitly starts both
  user services at session start.
- **No blind auto-detected monitor= in hyprland.conf.** The shipped
  `monitor=,preferred,auto,1` is a documented stopgap with explicit
  TODO instructions to replace it from `hyprctl monitors` after first
  boot (see "Mandatory first-boot TODOs" above).

---

## Tree

```
linux-rice/
├── README.md                                this
├── .gitignore
├── scripts/
│   ├── 00-base.sh                          official-repo install + makepkg.conf
│   ├── 10-aur.sh                           reviewed-PKGBUILD builds + repo-add
│   ├── 20-sddm.sh                          bare git clone + rollback snapshot
│   ├── 30-dotfiles.sh                      copiers config/ into ~/.config
│   └── 40-gaming.sh                        verifies gaming extras + templates
└── config/
    ├── hypr/
    │   ├── hyprland.conf                   compositor config (monitor= TODO!)
    │   ├── hyprpaper.conf                  wallpaper daemon (wallpaper TODO!)
    │   ├── hypridle.conf                   idle / lock / suspend listeners
    │   └── gpu-env.sh                      NVIDIA/Intel/AMD auto-detect env vars (source from shell rc)
    ├── nvim/
    │   └── init.lua                         single-file nvim config; pywal-driven, no plugins
    ├── waybar/
    │   ├── config                          top bar layout
    │   └── style.css                       pywal16 @import colors
    ├── swaync/
    │   ├── config.json                     notification center + widgets
    │   └── style.css                       pywal16 @import colors
    ├── rofi/
    │   └── config.rasi                      drun/run/window launcher
    ├── eww/
    │   ├── eww.yuck                        tiny demo widget
    │   └── eww.scss                        pywal16 @import colors
    ├── wlogout/
    │   ├── layout                          6 fields: lock/logout/suspend/hibernate/reboot/shutdown
    │   └── style.css                       pywal16 @import colors
    ├── ghostty/
    │   └── config                          primary terminal, Catppuccin Mocha baked
    ├── MangoHud/
    │   └── MangoHud.conf                   gaming HUD config
    └── applications/
        └── zed-handler.desktop             xdg-mime default for python/c/c++/lua/java/rust/json
```
