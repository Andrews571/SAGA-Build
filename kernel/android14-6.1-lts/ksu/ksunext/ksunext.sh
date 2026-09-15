#!/usr/bin/env bash

# ======================================================
# 🔑 ROOT SOLUTION — KernelSU-Next (android14-6.1-lts)
# ======================================================
# Repo: https://github.com/KernelSU-Next/KernelSU-Next

# setup.sh clones into ${GKI_ROOT}/KernelSU-Next and symlinks
# drivers/kernelsu -> KernelSU-Next/kernel, unlike ReSukiSU/SukiSU-Ultra's
# setup.sh which both produce a "KernelSU" dir directly — KSU_DIR below is
# intentionally different from resukisu.sh/sukisu.sh for this reason.
KSU_DIR="${KERNEL_SRC}/KernelSU-Next"
PATCHER_DIR="${SAGA_PATCH_DIR}/kernel/android14-6.1-lts/ksu/ksunext"

# ======================================================
# 1. KernelSU-Next
# ======================================================

log "Integrating KernelSU-Next..."
cd "$KERNEL_SRC"
if [ "${SUSFS_ENABLED:-false}" = "true" ]; then
    # Used to route to pershoot's dev-susfs fork here: official KernelSU-Next
    # had dropped the SUSFS-compatible hook API on its dev branch at the
    # time (see susfs.sh). That's no longer the case — susfs4ksu now ships
    # VFS Hooks v1.4, which official KernelSU-Next supports directly, so
    # this uses the same upstream source as the non-SUSFS path below
    # (2026-09). ksunext_susfs_fork stays a separate manifest.json pin from
    # plain ksunext — a commit can still be fine on its own and not yet
    # verified paired with SUSFS's patch, so checkpoint keeps testing them
    # independently — it's just no longer pershoot's fork underneath.
    log "SUSFS enabled — using official KernelSU-Next (susfs4ksu VFS Hooks v1.4)"
    KSUNEXT_SETUP_URL="https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/dev/kernel/setup.sh"
    KSUNEXT_SETUP_REF="${KSUNEXT_SUSFS_FORK_REF:-}"
else
    KSUNEXT_SETUP_URL="https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/dev/kernel/setup.sh"
    KSUNEXT_SETUP_REF="${KSUNEXT_REF:-}"
fi
KSUNEXT_SETUP=$(curl -LSs --fail --retry 3 --retry-all-errors --connect-timeout 30 \
    "$KSUNEXT_SETUP_URL") \
    || error "KernelSU-Next: failed to download setup.sh!"
[ -n "$KSUNEXT_SETUP" ] || error "KernelSU-Next: setup.sh is empty!"
echo "$KSUNEXT_SETUP" | grep -q "^#!" || error "KernelSU-Next: setup.sh looks invalid (no shebang)!"
if [ -n "$KSUNEXT_SETUP_REF" ]; then
    log "Pinning KernelSU-Next to ${KSUNEXT_SETUP_REF}"
    echo "$KSUNEXT_SETUP" | bash -s -- "$KSUNEXT_SETUP_REF" || error "KernelSU-Next: setup.sh failed!"
else
    echo "$KSUNEXT_SETUP" | bash || error "KernelSU-Next: setup.sh failed!"
fi
[ -d "$KSU_DIR" ] || error "KernelSU-Next: KernelSU-Next dir not found after setup!"
cd "$ROOT_DIR"
log "KernelSU-Next integrated ✅"

# ======================================================
# 2. Branding
# ======================================================

log "Applying SAGA branding..."
python3 "${PATCHER_DIR}/branding.py" "${KSU_DIR}/kernel/Kbuild" \
    || error "KernelSU-Next: branding patch failed!"
log "Branding applied ✅"

# ======================================================
# 2b. Version string (for Telegram caption)
# ======================================================
# Official KernelSU-Next's Kbuild: KSU_VERSION = 30000 + rev-list --count
# HEAD, KSU_VERSION_TAG = `git describe --tags --abbrev=0` at HEAD (fallback
# v0.0.1). Simple and purely local, like ReSukiSU's formula. Both the
# SUSFS and non-SUSFS paths use the same upstream repo/branch now (see
# section 1), so both compute this the same way — the merge-base-against-
# a-fork-branch dance this section used to do only mattered while SUSFS
# was routed through pershoot's differently-branched fork.
KSUNEXT_BASE_COMMIT="HEAD"

KSU_LOCAL_VERSION=$(git -C "$KSU_DIR" rev-list --count "$KSUNEXT_BASE_COMMIT" 2>/dev/null || echo 0)
KSU_VERSION_CODE=$((30000 + KSU_LOCAL_VERSION))
KSU_TAG_NAME=$(git -C "$KSU_DIR" describe --tags --abbrev=0 "$KSUNEXT_BASE_COMMIT" 2>/dev/null || echo "v0.0.1")
KSU_UAPI_VERSION=$(grep -oP 'KERNEL_SU_UAPI_VERSION\s*=\s*\K[0-9]+' "${KSU_DIR}/uapi/supercall.h" 2>/dev/null || echo "")

if [ -n "$KSU_UAPI_VERSION" ]; then
    KSUNEXT_VERSION_DISPLAY="${KSU_TAG_NAME} (${KSU_VERSION_CODE}/${KSU_UAPI_VERSION})"
else
    KSUNEXT_VERSION_DISPLAY="${KSU_TAG_NAME} (${KSU_VERSION_CODE})"
fi
echo "KSUNEXT_VERSION_DISPLAY=${KSUNEXT_VERSION_DISPLAY}" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true
log "Version: ${KSUNEXT_VERSION_DISPLAY}"

# ======================================================
# 3. Kconfig
# ======================================================
# No CONFIG_KPM here — KernelPatch is a SukiSU-Ultra/ReSukiSU feature,
# KernelSU-Next's Kconfig doesn't declare it.

log "Enabling KSU configs..."
if ! grep -q "^CONFIG_KSU=y" "${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"; then
    cat >> "${KERNEL_SRC}/arch/arm64/configs/gki_defconfig" << 'CONFIGS'
CONFIG_KSU=y
CONFIGS
fi
log "Configs enabled ✅"

log "KernelSU-Next ready ✅"
