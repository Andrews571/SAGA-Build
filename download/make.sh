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
    # KERNEL_REPO_URL and KERNEL_BRANCH are resolved once by
    # resolve_kernel_source() (functions.sh), called from build.sh/
    # arsenal.sh before this script runs — see that function for what
    # each KERNEL_SOURCE value ("live"/"live-staging"/"mirror") maps to.
    # Do not re-derive them here: that duplication is exactly what let
    # the "mirror" option silently clone "live" for months undetected.
    : "${KERNEL_REPO_URL:?KERNEL_REPO_URL not set — resolve_kernel_source() must run before download/make.sh}"
    log "Source: ${KERNEL_REPO_URL} @ ${KERNEL_BRANCH}"
    # This clones a full kernel source tree (~1.5GB working tree, ~240MB
    # of packed objects even at --depth=1) — a transfer that legitimately
    # takes 1-2 minutes on a good connection, giving a much bigger window
    # for a transient runner-network dip to trip the low-speed abort than
    # a typical small repo clone would. 1000 B/s for 30s (the previous
    # setting) proved too strict in practice — hit repeatedly on this
    # exact clone, confirmed not a broken/oversized repo (measured
    # directly: 1.5GB is normal for a full kernel tree). Loosened to
    # tolerate longer/slower dips without giving up early, while still
    # catching a genuinely dead connection (500 B/s sustained for a full
    # 60s is still a clear "this isn't going to finish" signal).
    git config --global http.connectTimeout 30
    git config --global http.lowSpeedLimit 500
    git config --global http.lowSpeedTime 60
    retry 5 run_quiet git clone -q --depth=1 \
        -b "$KERNEL_BRANCH" \
        "$KERNEL_REPO_URL" \
        "${KERNEL_DIR}/common" || error "Failed to clone kernel! (see output above)"
    log "Saving to cache..."
    mkdir -p "${HOME}/kernel-cache"
    rsync -a --delete "${KERNEL_DIR}/" "${HOME}/kernel-cache/"
fi
