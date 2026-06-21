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

log "Fixing task_mmu.c scope issue (zeromount call outside inode scope)..."
python3 - "${KERNEL_SRC}/fs/proc/task_mmu.c" << 'PYEOF'
import sys

with open(sys.argv[1]) as f:
    content = f.read()

broken = '''#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
\t\tsusfs_sus_kstat_spoof_show_map_vma(inode, &dev, &ino);
#endif // #ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
\t}

#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
#ifdef CONFIG_ZEROMOUNT
\t\tzeromount_spoof_mmap_metadata(inode, &dev, &ino);
#endif
orig_flow:
#endif // #ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT'''

fixed = '''#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
\t\tsusfs_sus_kstat_spoof_show_map_vma(inode, &dev, &ino);
#endif // #ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
#ifdef CONFIG_ZEROMOUNT
\t\tzeromount_spoof_mmap_metadata(inode, &dev, &ino);
#endif
\t}

#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
orig_flow:
#endif // #ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT'''

if broken in content:
    content = content.replace(broken, fixed)
    with open(sys.argv[1], 'w') as f:
        f.write(content)
    print("task_mmu.c scope fix applied.")
elif "zeromount_spoof_mmap_metadata" not in content:
    print("zeromount call not found in task_mmu.c, skipping (patch may have changed).")
else:
    print("Pattern already fixed or different, skipping.")
PYEOF

log "ZeroMount integrated ✅"
