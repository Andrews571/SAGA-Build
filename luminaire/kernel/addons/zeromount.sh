#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ZeroMount (VFS path redirection engine)
# ======================================================
# Repo: https://github.com/Enginex0/zeromount
# Patch source: https://github.com/Enginex0/Super-Builders
# Note: self-contained patch (creates fs/zeromount.c,
#       include/linux/zeromount.h, Kconfig + Makefile wiring).
#       Directory-listing injection hunks anchor on
#       CONFIG_KSU_SUSFS_SUS_PATH context — best paired with
#       SuSFS. Falls back gracefully (warn+continue) without it.

ZEROMOUNT_PATCH_URL="https://raw.githubusercontent.com/Enginex0/Super-Builders/main/android14-6.1/ReSukiSU/patches/60_zeromount-android14-6.1.patch"
ZEROMOUNT_PATCH="/tmp/60_zeromount-android14-6.1.patch"

log "Downloading ZeroMount kernel patch..."
retry 3 run_quiet curl -fSL "$ZEROMOUNT_PATCH_URL" -o "$ZEROMOUNT_PATCH" \
    || { warn "ZeroMount patch download failed — skipping"; return 0; }

log "Applying ZeroMount kernel patch..."
if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$ZEROMOUNT_PATCH" > /dev/null 2>&1; then
    log "ZeroMount patch already applied, skipping."
else
    patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$ZEROMOUNT_PATCH" \
        && log "ZeroMount patch applied ✅" \
        || warn "ZeroMount patch: some hunks failed — continuing (dir-listing injection may be degraded without SuSFS)"
fi

rm -f "$ZEROMOUNT_PATCH"
log "ZeroMount integrated ✅"
