#!/usr/bin/env bash

# ======================================================
# 🗜️ ADDON — ZRAM-IR (Immediate Recompression)
# By firelzrd, built on CONFIG_ZRAM_MULTI_COMP
# Repo: https://github.com/firelzrd/zram-ir
# ======================================================
# This kernel had NO multi-compressor ZRAM at all (confirmed: no
# CONFIG_ZRAM_MULTI_COMP, struct zcomp was single-stream only) — the
# gap to mainline's multi-comp introduction (Linux v6.2, right after
# this kernel's 6.1 base) was backported here first, then ZRAM-IR
# 1.2 (closest upstream target: 6.12.74) on top of it, both in the
# single patch below.
#
# Scope cut on purpose: only the write-time "immediate" trial path
# multi-comp infra is included (comps[] array, comp_algorithm /
# recomp_algorithm sysfs, zram_set/get_priority). Upstream's idle-time
# background recompression (/sys/block/zramX/recompress,
# zram_recompress()) was left out — ZRAM-IR doesn't need it, and it
# would have ~doubled this patch's surface for no benefit here.
#
# ABI note: ZRAM is CONFIG_ZRAM=m, built from this same source tree
# (not a separately-compiled vendor blob), and has zero vendor hooks —
# unlike lru_gen_folio/pg_data_t elsewhere in this kernel, struct zram
# was safe to restructure directly, no KABI_RESERVE juggling needed.
#
# Assumption inherited from upstream: configure recomp_algorithm
# priorities sequentially (1, then 2, then 3) with no gaps — prio_max
# is derived from a *count* of active compressors, not the highest
# configured index, so a gap (e.g. only priority 1 and 3 set, not 2)
# will silently skip priority 3 at write time.
#
# New sysctl: vm.zram_recomp_immediate (0-3, default 1) — how many
# extra priorities to try immediately at write time if the primary
# compressor doesn't beat huge_class_size. 0 = primary only.
#
# Default compressor pair:
#   primary   = lz4kd, but NOT set by this addon — the lz4kd addon's own
#               patch already makes `default ZRAM_DEF_COMP_LZ4KD` the
#               Kconfig choice default when CRYPTO_LZ4KD is enabled, so
#               adding it here too would define the same Kconfig symbol
#               twice (confirmed: lz4kd's remote patch also touches
#               drivers/block/zram/Kconfig, in the same choice block).
#               Select the lz4kd addon alongside this one for lz4kd to
#               actually be primary; without it, falls back to whatever
#               ZRAM_DEF_COMP is otherwise (lzo-rle stock default).
#   secondary = zstd, auto-registered in comp_algs[1] at zram_add()/
#               zram_reset_device() time — no init.rc/fstab write
#               needed, disksize_store()'s existing per-priority loop
#               creates both backends the first time zram is sized.
# Verified order-independent: applies clean whether lz4kd runs before or
# after this addon (their Kconfig hunks are 30+ lines apart, and neither
# touches zram_drv.c/.h/zcomp.c/.h that the other also touches).
#
# Unlike BBRv3's tcp_congestion_control, nothing on this device is
# known to keep rewriting comp_algorithm/recomp_algorithm after boot,
# so no enforcer is included. If your device's zram init script (in
# vendor/fstab, not this repo) explicitly writes comp_algorithm itself
# before disksize, that write will win over this default — check it
# if lz4kd doesn't end up active on /sys/block/zram0/comp_algorithm.

ZRAM_IR_PATCH="${LUMINAIRE_PATCH_DIR}/kernel/addons/zram-ir/zram-ir-android14-6.1-v1.patch"

log "🗜️ Applying ZRAM Multi-Comp + ZRAM-IR patch..."
[ -f "$ZRAM_IR_PATCH" ] || error "zram-ir: patch file not found at ${ZRAM_IR_PATCH}!"

if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$ZRAM_IR_PATCH" > /dev/null 2>&1; then
    log "zram-ir: patch already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward -d "$KERNEL_SRC" < "$ZRAM_IR_PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$ZRAM_IR_PATCH" \
        || error "zram-ir: patch apply failed!"
    log "zram-ir: patch applied ✅"
else
    error "zram-ir: patch does not apply cleanly — conflict or unsupported kernel source!"
fi

# CONFIG_ZRAM_MULTI_COMP defaults to 'n' (plain bool, no Kconfig
# 'default y'): without this, the patched code compiles but ZRAM
# stays single-stream (ZRAM_MAX_COMPS=1), same as before the patch.
GKI_DEFCONFIG="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "^CONFIG_ZRAM_MULTI_COMP=y" "$GKI_DEFCONFIG"; then
    cat >> "$GKI_DEFCONFIG" << 'CONFIGS'
# ZRAM-IR (Luminaire)
CONFIG_ZRAM_MULTI_COMP=y
CONFIG_ZRAM_DEF_RECOMP_ZSTD=y
CONFIGS
    log "zram-ir: CONFIG_ZRAM_MULTI_COMP + zstd secondary default forced in defconfig ✅"
    if ! grep -q "CONFIG_CRYPTO_LZ4KD" "$GKI_DEFCONFIG"; then
        log "ℹ️  zram-ir: lz4kd addon not detected in defconfig yet — primary compressor will be whatever ZRAM_DEF_COMP otherwise resolves to (stock lzo-rle), not lz4kd, unless the lz4kd addon is also selected."
    fi
fi

log "ZRAM-IR integrated ✅ (remember: recomp_algorithm still needs to be set from userspace before disksize)"
