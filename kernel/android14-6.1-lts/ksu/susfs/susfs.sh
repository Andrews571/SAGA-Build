#!/usr/bin/env bash

# ======================================================
# 🧬 SuSFS — shared apply logic (any KSU fork, android14-6.1-lts)
# ======================================================
# Repo: https://gitlab.com/simonpunk/susfs4ksu (same upstream for every
# root solution as of 2026-09 — see the pin-resolution comment below for
# the KSUNEXT history)

# SuSFS pin resolution — SukiSU-Ultra needs an exact commit paired with a
# matching susfs4ksu commit (community-verified combo, not just "old enough").
# ReSukiSU is generally compatible with SuSFS's branch tip, so it isn't
# pinned as tightly. kernel/checkpoint/scout.sh exports the right *_REF beforehand.
#
# KernelSU-Next used to be a special case routed to pershoot's fork: its
# dev branch had dropped the manual hook API (ksu_handle_*) that
# simonpunk/susfs4ksu's patch targeted at the time (confirmed by a real
# build with undefined ksu_handle_*/susfs_* symbols at link time, run
# 28714488530). That's no longer the situation — simonpunk/susfs4ksu now
# ships "VFS Hooks v1.4", which upstream KernelSU-Next supports directly
# (community pipelines, e.g. zzh20188/GKI_KernelSU_SUSFS, build official
# KernelSU-Next/KernelSU-Next + official simonpunk/susfs4ksu gki-android14-6.1
# together successfully as of SUSFS v1.5.9+ — no fork needed). Reverted to
# the same upstream source SUKISU/RESUKISU already use (2026-09).
#
# If this ever needs falling back to pershoot's fork again (upstream
# regresses, VFS Hooks breaks), that's still tracked in git history — see
# the commit that made this change.
if [ "$KERNEL_VARIANT" = "SUKISU" ]; then
    SUSFS_REF="${SUSFS_SUKISU_REF:-}"
    [ -n "$SUSFS_REF" ] || warn "SuSFS+SukiSU: no pin resolved — build will likely fail (see wishlist for known-good combos)"
    SUSFS_REPO="https://gitlab.com/simonpunk/susfs4ksu.git"
    SUSFS_BRANCH="gki-android14-6.1"
elif [ "$KERNEL_VARIANT" = "KSUNEXT" ]; then
    SUSFS_REF="${SUSFS_KSUNEXT_REF:-}"
    SUSFS_REPO="https://gitlab.com/simonpunk/susfs4ksu.git"
    SUSFS_BRANCH="gki-android14-6.1"
else
    SUSFS_REF="${SUSFS_RESUKISU_REF:-}"
    SUSFS_REPO="https://gitlab.com/simonpunk/susfs4ksu.git"
    SUSFS_BRANCH="gki-android14-6.1"
fi

KSU_DIR="${KSU_DIR:-${KERNEL_SRC}/KernelSU}"
SUSFS_DIR="/tmp/susfs4ksu"
PATCHER_DIR="${SAGA_PATCH_DIR}/kernel/android14-6.1-lts/ksu/susfs"

log "Cloning SuSFS (${SUSFS_BRANCH})..."
[ -d "$SUSFS_DIR" ] && rm -rf "$SUSFS_DIR"
git config --global http.connectTimeout 30
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 30
if [ -n "${SUSFS_REF:-}" ]; then
    log "Pinning SuSFS to ${SUSFS_REF}"
    mkdir -p "$SUSFS_DIR"
    (
        cd "$SUSFS_DIR"
        git init -q
        git remote add origin "$SUSFS_REPO"
        run_quiet git fetch --depth=1 origin "$SUSFS_REF" && git checkout -q FETCH_HEAD
    ) || {
        warn "SuSFS: server doesn't support fetching bare SHA — falling back to full clone"
        rm -rf "$SUSFS_DIR"
        retry 3 run_quiet git clone -q -b "$SUSFS_BRANCH" "$SUSFS_REPO" "$SUSFS_DIR" \
            || error "SuSFS: full clone fallback failed after 3 attempts!"
        if ! (cd "$SUSFS_DIR" && git checkout -q "$SUSFS_REF") 2>/dev/null; then
            # susfs4ksu's branches are maintained as a clean patch series on
            # top of a given kernel version, not append-only history —
            # simonpunk periodically rebases/force-pushes $SUSFS_BRANCH,
            # which silently orphans a previously-good pinned commit with no
            # relation to whether that commit ever actually built (confirmed
            # 2026-09-15: susfs_ksunext's pin, promoted hours earlier off a
            # real build success, had vanished from the branch — checked
            # both gitlab.com/simonpunk and the github.com/ShirkNeko mirror,
            # gone from both). A missing ref here means "this commit doesn't
            # exist anymore", not "this commit is bad" — so fall back to
            # whatever the branch currently has instead of hard-failing the
            # whole build over a pin that's stale through no fault of its
            # own. checkpoint/engine.sh still promotes/blacklists based on
            # whether THIS build succeeds, same as always — this only stops
            # a dead pin from being a hard blocker.
            warn "SuSFS: ${SUSFS_REF} no longer exists on ${SUSFS_BRANCH} (likely rebased upstream) — falling back to current branch tip"
            (cd "$SUSFS_DIR" && git checkout -q "$SUSFS_BRANCH") \
                || error "SuSFS: couldn't check out ${SUSFS_BRANCH} tip either!"
        fi
    }
else
    retry 3 run_quiet git clone -q --depth=1 -b "$SUSFS_BRANCH" "$SUSFS_REPO" "$SUSFS_DIR" \
        || error "SuSFS clone failed after 3 attempts!"
fi

log "Copying SuSFS source files..."
cp "${SUSFS_DIR}/kernel_patches/fs/susfs.c"                  "${KERNEL_SRC}/fs/susfs.c"
cp "${SUSFS_DIR}/kernel_patches/include/linux/susfs.h"       "${KERNEL_SRC}/include/linux/susfs.h"
cp "${SUSFS_DIR}/kernel_patches/include/linux/susfs_def.h"   "${KERNEL_SRC}/include/linux/susfs_def.h"
log "SuSFS source files copied ✅"

log "Applying SuSFS kernel patch..."
KERNEL_PATCH="${SUSFS_DIR}/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch"
if [ ! -f "$KERNEL_PATCH" ]; then
    # Don't return/exit here — a missing/renamed patch file upstream (this
    # has happened before, see the scope-minimized hooks history below)
    # must not skip the Kconfig injection and CONFIG_KSU_SUSFS enablement
    # further down. fix_namespace.py's own anchor-missing check will still
    # catch it hard if the underlying source structure changed too.
    warn "SuSFS kernel patch not found at ${KERNEL_PATCH} — skipping patch step, continuing with Kconfig/config setup"
elif patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$KERNEL_PATCH" > /dev/null 2>&1; then
    log "SuSFS kernel patch already applied, skipping."
else
    # Pre-patch: sublevel >= 157 adds #include <trace/hooks/blk.h> to namespace.c
    # which shifts context and causes hunk #1 to fail. Remove it temporarily so
    # the patch can match, then restore after.
    # Traced to upstream commit 60dddcb8f9 (Wang Jianzheng, 2024-06-07,
    # kernel/common fs/namespace.c) — verify against that commit if this
    # threshold ever needs re-checking.
    if [ "${SUBLEVEL:-0}" -ge 157 ]; then
        log "Pre-patch: removing blk.h from namespace.c for context match (sublevel ${SUBLEVEL})..."
        sed -i '/^#include <trace\/hooks\/blk\.h>$/d' "${KERNEL_SRC}/fs/namespace.c"
    fi

    patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$KERNEL_PATCH" \
        && log "SuSFS kernel patch applied ✅" \
        || warn "SuSFS kernel patch: some hunks failed — continuing"

    # Post-patch: restore blk.h if it was removed and patch didn't re-add it
    if [ "${SUBLEVEL:-0}" -ge 157 ] && ! grep -qF '#include <trace/hooks/blk.h>' "${KERNEL_SRC}/fs/namespace.c"; then
        log "Post-patch: restoring blk.h to namespace.c..."
        sed -i '/^#include "internal\.h"$/a #include <trace\/hooks\/blk.h>' "${KERNEL_SRC}/fs/namespace.c"
        # Verify the restore actually landed — if the "internal.h" anchor was
        # itself missing/renamed upstream, sed would silently no-op and we'd
        # lose blk.h permanently without anyone noticing until link time.
        grep -qF '#include <trace/hooks/blk.h>' "${KERNEL_SRC}/fs/namespace.c" \
            || error "SuSFS: failed to restore blk.h include in namespace.c — internal.h anchor may have changed upstream!"
    fi

    # Cleanup any leftover .rej files
    find "$KERNEL_SRC" -name "*.rej" -delete 2>/dev/null || true
fi

log "Fixing namespace.c susfs declarations (safety fallback)..."
python3 "${PATCHER_DIR}/fix_namespace.py" "${KERNEL_SRC}/fs/namespace.c" \
    || error "SuSFS: namespace.c fix failed!"
log "namespace.c fixed ✅"

# NOTE (stale as of 2026-09, kept for history): this used to explain why
# nothing needed to happen here for KSUNEXT — pershoot's dev-susfs fork
# shipped the manual-hook/SuSFS integration directly in KernelSU-Next's
# own source (kernel/feature, kernel/hook, kernel/selinux, etc.), so the
# patch step above used to warn-and-skip for it (no
# 50_add_susfs_in_gki-android14-6.1.patch in that fork's layout) and there
# was nothing left to apply here. Now that KSUNEXT+SUSFS points at official
# KernelSU-Next + simonpunk/susfs4ksu (see the pin-resolution comment near
# the top of this file), KSUNEXT goes through the exact same patch
# application as SUKISU/RESUKISU above — this section is no longer a
# special case. Left unverified by an actual build+boot as of this
# comment; treat as needing that confirmation, not as settled.

rm -rf "$SUSFS_DIR"

log "Ensuring KSU_SUSFS Kconfig declarations exist..."
KSU_KCONFIG="${KSU_DIR}/kernel/Kconfig"
if [ -f "$KSU_KCONFIG" ] && grep -q "^config KSU_SUSFS$" "$KSU_KCONFIG"; then
    log "KSU_SUSFS already declared by this fork, skipping injection."
else
    python3 "${PATCHER_DIR}/kconfig_inject.py" "$KSU_KCONFIG" \
        || error "SuSFS: Kconfig inject failed!"
    log "KSU_SUSFS Kconfig injected ✅"
fi

log "Enabling SuSFS configs..."
if ! grep -q "^CONFIG_KSU_SUSFS=y" "${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"; then
    cat >> "${KERNEL_SRC}/arch/arm64/configs/gki_defconfig" << 'CONFIGS'
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
CONFIGS
    # SUS_SU (fake_state/fake_status/ksu_selinux_hide_enabled) was disabled
    # here because it wasn't implemented in pershoot/KernelSU-Next's
    # dev-susfs fork's own selinux.c/selinuxfs.c — only referenced there,
    # with no definitions, causing undefined-symbol link errors for
    # KSUNEXT+SUSFS specifically (confirmed via real build, run
    # 28793310460). Now that KSUNEXT+SUSFS uses official KernelSU-Next
    # instead of that fork (see susfs.sh's pin-resolution comment), this
    # specific reason no longer applies — but that's not the same as
    # confirming official KernelSU-Next's selinux.c implements sus_su.c
    # fully. Left disabled here until a real build confirms one way or the
    # other; safe to try re-enabling for KSUNEXT as a follow-up test once
    # the base switch itself is verified.
    if [ "$KERNEL_VARIANT" != "KSUNEXT" ]; then
        echo "CONFIG_KSU_SUSFS_SUS_SU=y" >> "${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
    fi
fi
log "SuSFS configs enabled ✅"

log "SuSFS integrated ✅"
