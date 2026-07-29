#!/usr/bin/env bash

# ======================================================
# 🩹 CORE — Tick rate (CONFIG_HZ) choice
# ======================================================
# kernel/Kconfig.hz upstream only offers 100/250/300/1000 — there's no
# 500 Hz option in mainline. hz500.patch adds it as a real Kconfig choice
# (matching the existing entries' style) rather than hacking CONFIG_HZ's
# int value in after the fact: CONFIG_HZ is itself computed from whichever
# HZ_xxx bool is selected (`default 500 if HZ_500`, see the choice block),
# and other code in tree may check CONFIG_HZ_xxx directly rather than the
# int — so the selection has to go through a real choice option to stay
# internally consistent.
#
# Applied unconditionally (like the other kernel/core/*_catchup scripts)
# so the HZ_500 option always exists in the tree; TICK_RATE (a
# workflow_dispatch input, one of 100/250/500/1000, see build.yml) then
# picks which one actually lands in gki_defconfig for this build, below.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/hz500.patch"

log "🩹 Applying HZ_500 Kconfig choice patch..."
cd "${KERNEL_SRC}"

if git apply --check --reverse "$PATCH_FILE" > /dev/null 2>&1; then
    log "HZ_500 Kconfig patch: already applied, skipping."
elif git apply --check "$PATCH_FILE" > /dev/null 2>&1; then
    git apply "$PATCH_FILE" || error "HZ_500 Kconfig patch: apply failed!"
    log "HZ_500 Kconfig patch: applied ✅"
else
    error "HZ_500 Kconfig patch: does not apply cleanly — kernel source may have changed since this was written, needs re-verification!"
fi

cd "${ROOT_DIR}"

# ------------------------------------------------------
# Pick the actual tick rate for this build
# ------------------------------------------------------
TICK_RATE="${TICK_RATE:-250}"

case "$TICK_RATE" in
    100|250|500|1000) ;;
    *) error "Tick rate: unrecognized TICK_RATE '${TICK_RATE}' — expected 100, 250, 500, or 1000." ;;
esac

DEFCONFIG_FILE="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"

# Strip any pre-existing CONFIG_HZ_*/CONFIG_HZ= lines first — it's a
# Kconfig `choice`, so only one HZ_xxx may be =y at a time, and leaving a
# stale one in gki_defconfig alongside the new one would make the actual
# result depend on Kconfig's choice-conflict resolution instead of on
# TICK_RATE. Nothing sets one today (confirmed: gki_defconfig has no
# CONFIG_HZ line at all, so this is defensive, not a fix for a known
# clash), but cheap insurance against that changing later.
sed -i '/^# Tick rate (SAGA)$/d; /^CONFIG_HZ_[0-9]*=y$/d; /^CONFIG_HZ=[0-9]*$/d' "$DEFCONFIG_FILE"

cat >> "$DEFCONFIG_FILE" << EOF
# Tick rate (SAGA)
CONFIG_HZ_${TICK_RATE}=y
EOF

log "Tick rate: CONFIG_HZ_${TICK_RATE}=y set ✅"

log "Tick rate choice integrated ✅"
