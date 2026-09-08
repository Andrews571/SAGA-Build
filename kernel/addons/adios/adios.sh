#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS (Adaptive Deadline I/O Scheduler)
# by Masahito Suzuki (firelzrd)
# Repo: https://github.com/firelzrd/adios
# ======================================================
# v3.3.4-SAGA: base v3.2.0 backport (elevator_get() instead of
# elevator_find_get() -- doesn't exist on 6.1, mq-deadline preserved as
# fallback default, NULL pointer fix in adios_completed_request() for
# UFS MCQ, subsys_initcall() timing fix, boot-time genhd.c enforcer)
# MERGED with what used to be the separate "adios-tunable" addon's LM/
# sysfs extension (model confidence gating, auto-scaled batch limits,
# auto-decay detection, device-class heuristic, interactive-read boost,
# adaptive depth controller, 15 tunable sysfs knobs) plus fixes from 3
# independent review rounds. adios-tunable is now a SEPARATE, optional
# addon again (see kernel/addons/adios-tunable/) -- it only carries the
# small genhd logging bonus now, nothing this file doesn't already have.
# Full rationale for every individual fix/feature is in this patch's own
# header — see kernel/addons/adios/adios-android14-6.1-v3.3.4.patch.

ADIOS_PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios/adios-android14-6.1-v3.3.4.patch"

log "📦 Applying ADIOS I/O scheduler patch (v3.3.4-SAGA, LM/sysfs tunables merged in)..."
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
    cat >> "$DEFCONFIG_FILE" << 'DEFCONFIG_EOF'
# ADIOS I/O scheduler (SAGA)
CONFIG_MQ_IOSCHED_ADIOS=y
CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y
DEFCONFIG_EOF
    log "ADIOS: CONFIG_MQ_IOSCHED_ADIOS + DEFAULT_ADIOS enabled ✅"
fi

log "ADIOS I/O scheduler integrated ✅"

ADIOS_VERSION=$(basename "$ADIOS_PATCH" | sed -n 's/.*-\(v[0-9.]*\)\.patch$/\1/p')
if [ -n "$ADIOS_VERSION" ] && [ -n "${GITHUB_ENV:-}" ]; then
    echo "ADIOS_VERSION=${ADIOS_VERSION}" >> "$GITHUB_ENV"
fi
