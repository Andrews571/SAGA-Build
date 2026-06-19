#!/usr/bin/env bash

# ======================================================
# 🏷️ BRANDING — CONFIG + APPLY
# ======================================================

export KERNEL_NAME="Luminaire"
export BUILD_USER="chainonyourdoor"
export BUILD_HOST="LuminaireCI"

export KBUILD_BUILD_USER="$BUILD_USER"
export KBUILD_BUILD_HOST="$BUILD_HOST"
export LOCALVERSION="-${ANDROID_VERSION}-${KMI_GENERATION}-${KERNEL_NAME}"
export KBUILD_BUILD_TIMESTAMP="$(date '+%a %b %d %T %Z %Y')"
# -------------------------------------------------------
# MAKE — env vars are enough, kernel reads them directly
# -------------------------------------------------------
if [ "$BUILD_SYSTEM" = "MAKE" ]; then
    log "Branding: ${BUILD_USER}@${BUILD_HOST} | ${LOCALVERSION} ✅"
    return 0
fi

# -------------------------------------------------------
# KLEAF — Bazel doesn't read env vars or build.config
# -------------------------------------------------------

# 1. LOCALVERSION via CONFIG_LOCALVERSION in gki_defconfig
#    (gets canonicalized by two-pass in kleaf.sh automatically)
DEFCONFIG="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if [ -f "$DEFCONFIG" ]; then
    if grep -q "^CONFIG_LOCALVERSION=" "$DEFCONFIG"; then
        sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"-${KERNEL_NAME}\"|" "$DEFCONFIG"
    else
        echo "CONFIG_LOCALVERSION=\"-${KERNEL_NAME}\"" >> "$DEFCONFIG"
    fi
    log "Kleaf CONFIG_LOCALVERSION patched ✅"
fi

# 2. build-user@build-host via scripts/mkcompile_h
#    AOSP GKI hardcodes build-user/build-host in mkcompile_h for reproducibility
#    We patch it directly so Kleaf picks up our values during kernel compile
MKCOMPILE_H="${KERNEL_SRC}/scripts/mkcompile_h"
if [ -f "$MKCOMPILE_H" ]; then
    sed -i "s/\(LINUX_COMPILE_BY=\).*/\1\"${BUILD_USER}\"/" "$MKCOMPILE_H"
    sed -i "s/\(LINUX_COMPILE_HOST=\).*/\1\"${BUILD_HOST}\"/" "$MKCOMPILE_H"
    log "mkcompile_h patched ✅"
    grep -n "LINUX_COMPILE_BY\|LINUX_COMPILE_HOST" "$MKCOMPILE_H" \
        | while IFS= read -r l; do log "  $l"; done || true
else
    log "⚠️ mkcompile_h not found at: $MKCOMPILE_H"
fi

# 3. BUILD_TIMESTAMP via stamp.bzl — fix SOURCE_DATE_EPOCH=0 (epoch 1970)
BUILD_EPOCH="$(date +%s)"
STAMP_BZL="${KERNEL_DIR}/build/kernel/kleaf/impl/stamp.bzl"
if [ -f "$STAMP_BZL" ]; then
    sed -i "s/export SOURCE_DATE_EPOCH=0/export SOURCE_DATE_EPOCH=${BUILD_EPOCH}/" "$STAMP_BZL"
    log "stamp.bzl SOURCE_DATE_EPOCH patched ✅"
else
    log "⚠️ stamp.bzl not found at: $STAMP_BZL"
fi

# 4. Kleaf action_env flags (passed to KLEAF_ARGS in kleaf.sh)
BRANDING_KLEAF_ARGS=(
    --noincompatible_strict_action_env
    --action_env=KBUILD_BUILD_USER="${BUILD_USER}"
    --action_env=KBUILD_BUILD_HOST="${BUILD_HOST}"
)

log "Branding: ${BUILD_USER}@${BUILD_HOST} | -${KERNEL_NAME} ✅"
