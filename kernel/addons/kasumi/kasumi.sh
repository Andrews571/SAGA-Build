#!/usr/bin/env bash

# ======================================================
# 🥷 ADDON — Kasumi (path manipulation/hiding LKM)
# by Anatdx
# Repo: https://github.com/Anatdx/Kasumi
# ======================================================
# Kasumi is NOT an in-tree kernel patch — it's an out-of-tree LKM
# (kasumi_lkm.ko) built separately against a prepared kernel tree
# (needs Module.symvers, which only exists after the main kernel build
# finishes). This script only clones the source; the actual module
# compile happens in kernel/addons/kasumi/postbuild.sh (run_postbuild() in
# build.sh, after run_build() finishes), and packaging
# into the AK3 zip happens in release/anykernel.sh. This is a different
# shape from every other addon here (all of which patch source/defconfig
# pre-build) — don't move the clone logic into a patch step by mistake.
#
# EXPERIMENTAL: hooks VFS and syscall hot paths (openat/statx/newfstatat/
# faccessat/getxattr/readdir/etc). Upstream's own README says "use in
# controlled environments only" — default is off (build.yml), and the
# resulting .ko is shipped for manual insmod/ksud insmod, not auto-loaded.

KASUMI_REPO="https://github.com/Anatdx/Kasumi.git"
KASUMI_SRC_DIR="${WORKSPACE_DIR}/kasumi"

log "🥷 Fetching Kasumi source..."

if [ -d "${KASUMI_SRC_DIR}/.git" ]; then
    log "Kasumi: source already present, skipping clone."
else
    rm -rf "${KASUMI_SRC_DIR}"
    retry 3 run_quiet git clone -q --depth=1 "${KASUMI_REPO}" "${KASUMI_SRC_DIR}" \
        || error "Kasumi: failed to clone source!"
fi

[ -d "${KASUMI_SRC_DIR}/src" ] || error "Kasumi: cloned repo missing src/ — layout may have changed upstream!"

# Kasumi resolves non-exported kernel symbols (kallsyms_lookup_name and
# friends) at runtime — needs the full kallsyms table, not just exported
# ones. Inject directly into gki_defconfig (before `make defconfig` runs),
# same reasoning/pattern as bbrv3.sh: scripts/config post-processing in
# defconfig.sh runs too late for constraints like this that other Kconfig
# options key off of.
GKI_DEFCONFIG="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "CONFIG_KALLSYMS_ALL" "$GKI_DEFCONFIG"; then
    cat >> "$GKI_DEFCONFIG" << 'EOF'
# Kasumi requires full kallsyms (Luminaire)
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
EOF
    log "Kasumi: CONFIG_KALLSYMS_ALL injected into gki_defconfig ✅"
fi

# Consumed later by kernel/addons/kasumi/postbuild.sh (run_postbuild() in
# build.sh, after run_build() finishes) and release/anykernel.sh
# (packaging). Exported so it survives into those later stages. No separate
# "enabled" flag needed — run_postbuild() gates on membership in $ADDONS,
# same as run_addons() does for this script.
export KASUMI_SRC_DIR

log "Kasumi source ready at ${KASUMI_SRC_DIR} ✅ (module build deferred to post-build stage)"
