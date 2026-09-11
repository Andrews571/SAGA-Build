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
# independent review rounds.
#
# v3.3.5-SAGA: ports the flush/barrier simplification from firelzrd's
# own upstream v3.2.0 -> v3.3.0 update (github.com/firelzrd/adios).
# Removes ADIOS's own Tier-1 REQ_OP_FLUSH barrier queue -- the generic
# block layer's flush state machine (block/blk-flush.c) already
# handles REQ_PREFLUSH/REQ_FUA ordering correctly (predates 2.6.37),
# so ADIOS's own barrier_queue/barrier_lock/release_barrier_requests()
# were redundant complexity. Deliberately does NOT port upstream's
# other v3.3.0 change (the shallow_depth/to_word_depth fix) -- that
# fix targets a bug introduced by sbitmap's shallow_depth unit
# convention change in Linux 6.12, which this android14-6.1 tree
# predates; porting it here would introduce a unit mismatch, not fix
# one.
#
# Also in v3.3.5-SAGA: what used to be the separate "adios-topapp"
# addon is now merged directly into this file (no more separate addon
# -- remove "adios-topapp" from ADDONS= if it's still listed, its
# folder is no longer needed). Adds a bounded, sysfs-tunable IO
# deadline bonus (topapp_deadline_bonus) for requests whose IO
# priority marks them latency-critical (IOPRIO_CLASS_RT, or BE level
# 0-1 -- e.g. what Android's task_profiles.json commonly assigns to
# the top-app cgroup when configured to do so). Starts at 0 (disabled)
# and self-activates via an in-kernel one-shot timer
# (topapp_activation_delay_ms, default 90s after this scheduler
# attaches to its queue) -- no init.rc, no device-tree change, no
# kernel module needed for it to end up enabled.
#
# Full rationale for every individual fix/feature is in this patch's own
# header — see kernel/addons/adios/adios-android14-6.1-v3.3.5.patch.

ADIOS_PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios/adios-android14-6.1-v3.3.5.patch"

log "📦 Applying ADIOS I/O scheduler patch (v3.3.5-SAGA, top-app deadline bonus + upstream flush-barrier simplification merged in)..."
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

log "ADIOS I/O scheduler integrated ✅ — top-app deadline bonus starts DISABLED, self-activates ~90s after queue attach (kernel.topapp_activation_delay_ms to tune)"

ADIOS_VERSION=$(basename "$ADIOS_PATCH" | sed -n 's/.*-\(v[0-9.]*\)\.patch$/\1/p')
if [ -n "$ADIOS_VERSION" ] && [ -n "${GITHUB_ENV:-}" ]; then
    echo "ADIOS_VERSION=${ADIOS_VERSION}" >> "$GITHUB_ENV"
fi
