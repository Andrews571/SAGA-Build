#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS (Adaptive Deadline I/O Scheduler)
# by Masahito Suzuki (firelzrd)
# Repo: https://github.com/firelzrd/adios
# ======================================================
# Backport to android14-6.1: elevator_get() instead of elevator_find_get()
# (doesn't exist on 6.1), mq-deadline preserved as fallback default when
# ADIOS default is not selected (this tree has no SSG scheduler — see the
# patch header for how that was confirmed), a NULL pointer fix in
# adios_completed_request() for UFS MCQ (rq->elv.priv[0] can be NULL for
# requests that never went through elevator insert), and adios_init()
# moved from module_init() to subsys_initcall() so it always registers
# before the UFS-MTK platform driver (also device_initcall-level) gets a
# chance to probe — otherwise CONFIG_MQ_IOSCHED_DEFAULT_ADIOS is a
# link-order coin flip per block device, not a real guarantee.

ADIOS_PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios/adios-android14-6.1-v3.2.0.patch"

log "📦 Applying ADIOS I/O scheduler patch..."
[ -f "$ADIOS_PATCH" ] || error "ADIOS: patch file not found at ${ADIOS_PATCH}!"

if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$ADIOS_PATCH" > /dev/null 2>&1; then
    log "ADIOS: patch already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward -d "$KERNEL_SRC" < "$ADIOS_PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$ADIOS_PATCH" \
        || error "ADIOS: patch apply failed!"
    log "ADIOS: patch applied ✅"
else
    error "ADIOS: patch does not apply cleanly — conflict or unsupported kernel source!"
fi

DEFCONFIG_FILE="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "^CONFIG_MQ_IOSCHED_ADIOS=y" "$DEFCONFIG_FILE"; then
    cat >> "$DEFCONFIG_FILE" << 'EOF'
# ADIOS I/O scheduler (SAGA)
CONFIG_MQ_IOSCHED_ADIOS=y
CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y
EOF
    log "ADIOS: CONFIG_MQ_IOSCHED_ADIOS + DEFAULT_ADIOS enabled ✅"
fi

log "ADIOS I/O scheduler integrated ✅"

# Extracted from the patch filename itself (e.g. "...-v3.2.0.patch" -> "v3.2.0")
# rather than hardcoded, so it can't silently go stale if the patch is ever
# bumped to a new ADIOS release — same reasoning as SUSFS_VER's grep in
# telegram.sh. Only meaningful within this job (GITHUB_ENV), consumed later
# by telegram.sh for the per-variant JSON artifact that feeds the channel
# post's Features page.
ADIOS_VERSION=$(basename "$ADIOS_PATCH" | sed -n 's/.*-\(v[0-9.]*\)\.patch$/\1/p')
if [ -n "$ADIOS_VERSION" ] && [ -n "${GITHUB_ENV:-}" ]; then
    echo "ADIOS_VERSION=${ADIOS_VERSION}" >> "$GITHUB_ENV"
fi
