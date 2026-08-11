#!/usr/bin/env bash
# gpu-env.sh — app-level env vars for the rice. Source from your shell rc:
#
#     # in ~/.zshrc or ~/.bashrc, near the top:
#     if [ -f ~/.config/hypr/gpu-env.sh ]; then
#         . ~/.config/hypr/gpu-env.sh
#     fi
#
# This file AUTO-DETECTS the running GPU at shell start and only sets
# the env vars that matter for that vendor. Adding/removing env vars
# affects what's inherited by games launched from Steam/Proton, native
# Vulkan games, and any CLI tool that respects $LIBVA_DRIVER_NAME,
# $MESA_*, $NV_*, $__GL_*, $VK_* etc.
#
# Detection: looks for the running GPU by parsing `lspci -nn`.
# Both `lspci` and `glxinfo` are installed by 00-base.sh (pciutils is
# a base dep; glxinfo comes from `mesa-demos` — added to 00-base).

gpu_env_loaded=0

# ---- Detect vendor ------------------------------------------------------
gpu_vendor() {
    if ! command -v lspci >/dev/null 2>&1; then
        echo unknown
        return
    fi
    local line
    line=$(lspci -nn | grep -Ei ' VGA compatible controller: ' | head -n1)
    case "$line" in
        *NVIDIA*) echo nvidia ;;
        *Advanced Micro Devices*) echo amd ;;
        *Intel*) echo intel ;;
        *) echo unknown ;;
    esac
}

VENDOR=$(gpu_vendor)

# ---- Common (any GPU) ---------------------------------------------------
export DRI_PRIME=1                              # honour PRIME offload if present (laptops)
export VK_ICD_FILENAMES_ALL_KNOWN=1            # don't gate ICD files

# ---- NVIDIA-specific -----------------------------------------------------
if [ "$VENDOR" = nvidia ]; then
    # Frame pacing + threaded GL optimisations (mostly win for Proton/VK):
    export __GL_THREADED_OPTIMIZATIONS=1
    export __GL_GSYNC_ALLOWED=1
    export __GL_VRR_ALLOWED=1
    # VDPAU/VAAPI routing  (NVIDIA:
    export VDPAU_DRIVER=nvidia
    export LIBVA_DRIVER_NAME=nvidia
    # Proton/Vulkan picks the right ICD automatically since Steam ships its
    # own loader overrides; we leave VK_ICD_FILENAMES unset so mesa/nvidia
    # both can co-register when running PRIME.

# ---- AMD/Intel (Mesa) ----------------------------------------------------
elif [ "$VENDOR" = amd ] || [ "$VENDOR" = intel ]; then
    : MESA_GLSL_CACHE_DIR set by GLEW - keep default
    export Mesa_GL_VERSION_OVERRIDE=4.6        # some old games prefer this
    export Mesa_GLSL_CACHE_DISABLE=false       # default, but explicit

    if [ "$VENDOR" = intel ]; then
        export LIBVA_DRIVER_NAME=iHD           # Broadwell+; on Haswell use i965
        export VDPAU_DRIVER=va_gl
    else
        export LIBVA_DRIVER_NAME=radeonsi      # Mesa VA-API on AMD
        export VDPAU_DRIVER=radeonsi            # fallback if VPDU hits
        export Mesa_GL_VERSION_OVERRIDE=4.6
        export radeonsi_shader_cache_enable=true
    fi
fi

unset -f gpu_vendor
gpu_env_loaded=1
