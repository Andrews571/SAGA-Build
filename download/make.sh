#!/usr/bin/env bash

# ======================================================
# 📥 DOWNLOAD — MAKE (Git Clone)
# ======================================================

if [ "${USE_KERNEL_CACHE}" = "true" ] && [ -d "${HOME}/kernel-cache/common" ]; then
    log "Restoring kernel source from cache..."
    cp -a "${HOME}/kernel-cache/." "${KERNEL_DIR}/"
    log "Kernel source restored ✅ ($(cache_freshness_note))"
else
    log "Cloning kernel source..."
    # KERNEL_SOURCE ("live" or "mirror", see build.yml's kernel_source
    # input) picks between the two repos kernel-source.yml maintains:
    # SAGA-Kernel-<ver> (Google GKI + linux-stable catch-up, what builds
    # normally want) or SAGA-Kernel-<ver>-mirror (pure Google GKI, no
    # catch-up — a clean baseline for comparison/bisection). Both use the
    # same "-live" branch name (see kernel-source.yml).
    if [ "${KERNEL_SOURCE:-live}" = "mirror" ]; then
        KERNEL_REPO_URL="https://github.com/Andrews571/SAGA-Kernel-${KERNEL_VERSION}-mirror"
    else
        KERNEL_REPO_URL="https://github.com/Andrews571/SAGA-Kernel-${KERNEL_VERSION}"
    fi
    log "Source: ${KERNEL_REPO_URL} @ ${KERNEL_BRANCH}"
    git config --global http.connectTimeout 30
    git config --global http.lowSpeedLimit 1000
    git config --global http.lowSpeedTime 30
    retry 5 run_quiet git clone -q --depth=1 \
        -b "$KERNEL_BRANCH" \
        "$KERNEL_REPO_URL" \
        "${KERNEL_DIR}/common" || error "Failed to clone kernel! (see output above)"
    log "Saving to cache..."
    mkdir -p "${HOME}/kernel-cache"
    rsync -a --delete "${KERNEL_DIR}/" "${HOME}/kernel-cache/"
fi
