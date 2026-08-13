#!/usr/bin/env bash
# ======================================================
# ✨ SAGA — Build Orchestrator
# ======================================================

set -eo pipefail

# GitHub Actions captures stdout and stderr as separate buffered streams and
# doesn't guarantee their relative order in the rendered log. log()/warn()/
# error() write to stderr while ::group::/::endgroup:: (below) write to
# stdout, so without this, log lines can render outside the ::group:: block
# they were actually written inside of. Merging stderr into stdout here
# keeps everything on one stream, preserving actual write order.
exec 2>&1

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# ======================================================
# ⚙️ CONFIGURATION
# ======================================================

KERNEL_VERSION="${KERNEL_VERSION:?KERNEL_VERSION is not set}"

# DRY_RUN skips the actual compile (see build/make.sh) so
# the rest of the pipeline can be exercised quickly after a refactor. It's
# derived in build.yml from RUN_MODE=="Dry Run", so it can never disagree
# with RUN_MODE by the time it reaches here.

ANDROID_VERSION="$(resolve_android_version)"
resolve_kernel_source  # sets KERNEL_REPO_URL + KERNEL_BRANCH — see functions.sh

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Bootstrap path — needed before run_setup() sources 00_paths.sh
SAGA_PATCH_DIR="${ROOT_DIR}"

# ======================================================
# 🚀 MAIN
# ======================================================

main() {
    echo "========================================"
    echo "  ✨ SAGA ✨"
    echo "========================================"
    echo "  🏷️ ${KERNEL_VARIANT}$([ "$SUSFS_ENABLED" = "true" ] && [ "$KERNEL_VARIANT" != "VANILLA" ] && echo "+SUSFS")"
    echo "  $(mode_emoji "$RUN_MODE") ${RUN_MODE}"
    echo "  🖥️ CPU: $(nproc --all) cores"
    echo "  💾 RAM: $(free -h | grep Mem | awk '{print $2}')"
    echo "  📅 $(date)"
    echo "========================================"

    run_setup

    # Wait for background apt install (started in 01_deps.sh) to finish —
    # setup/02_ccache.sh (cmake/ninja/g++) and build/make.sh (bc/bison/flex)
    # need these packages present before they run. arsenal.sh already did
    # this; build.sh previously did not, which could race on a fresh runner.
    echo "::group::⏳ Dependencies"
    wait_for_apt
    echo "::endgroup::"

    [ -d "$VERSION_PATCH_DIR" ] \
        || error "Kernel version ${KERNEL_VERSION} is not yet supported — missing ${VERSION_PATCH_DIR} (no KSU/patches implemented for this version)"

    mkdir -p "$KERNEL_DIR" "$OUT_DIR"

    restore_kernel_source
    run_branding
    run_variant
    mark_stage_ok CHECKPOINT_VARIANT_OK
    run_core
    run_addons
    mark_stage_ok CHECKPOINT_ADDONS_OK
    run_build
    mark_stage_ok CHECKPOINT_BUILD_OK
    run_postbuild

    if [ "${RUN_MODE^^}" = "WARM RUN" ]; then
        echo "========================================"
        echo "  $(mode_emoji "$RUN_MODE") ${RUN_MODE} Complete! $(mode_emoji "$RUN_MODE")"
        echo "  🏷️ ${KERNEL_VARIANT}$([ "$SUSFS_ENABLED" = "true" ] && [ "$KERNEL_VARIANT" != "VANILLA" ] && echo "+SUSFS")"
        echo "========================================"
        exit 0
    fi

    run_release

    echo "========================================"
    echo "  $(mode_emoji "$RUN_MODE") ${RUN_MODE} Complete! $(mode_emoji "$RUN_MODE")"
    echo "  🏷️ ${KERNEL_VARIANT}$([ "$SUSFS_ENABLED" = "true" ] && [ "$KERNEL_VARIANT" != "VANILLA" ] && echo "+SUSFS")"
    echo "========================================"
}


# ======================================================
# 📥 KERNEL SOURCE
# ======================================================
# (run_setup() is defined in functions.sh, shared with arsenal.sh)

restore_kernel_source() {
    echo "::group::📥 Kernel Source"
    source "${SAGA_PATCH_DIR}/download/make.sh"
    log "Kernel source ready ✅"
    echo "::endgroup::"
}

# ======================================================
# 🔖 BRANDING
# ======================================================

run_branding() {
    echo "::group::🔖 Branding"
    SUBLEVEL="$(grep '^SUBLEVEL = ' "${KERNEL_SRC}/Makefile" | awk '{print $3}')"
    [ -n "$SUBLEVEL" ] || error "SUBLEVEL not found in kernel Makefile — kernel source may be missing or corrupted!"
    KMI_GENERATION="$(grep '^KMI_GENERATION=' \
        "${KERNEL_SRC}/build.config.common" \
        "${KERNEL_SRC}/build.config.constants" 2>/dev/null | head -1 | cut -d= -f2)"
    [ -z "$KMI_GENERATION" ] && error "KMI_GENERATION not found!"
    export SUBLEVEL KMI_GENERATION
    echo "SUBLEVEL=${SUBLEVEL}" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true
    source "${SAGA_PATCH_DIR}/kernel/branding.sh" || error "Branding failed!"
    echo "::endgroup::"
}

# ======================================================
# 🍀 ROOT SOLUTION & SUSFS
# ======================================================

run_variant() {
    local script="${VERSION_PATCH_DIR}/ksu/${KERNEL_VARIANT,,}/${KERNEL_VARIANT,,}.sh"
    if [ -f "$script" ]; then
        echo "::group::🍀 Root Solution (${KERNEL_VARIANT})"
        source "$script" || error "Root solution script failed: $(basename "$script")"
        echo "::endgroup::"
    fi

    if [ "$SUSFS_ENABLED" = "true" ] && [ "$KERNEL_VARIANT" != "VANILLA" ]; then
        local susfs_script="${VERSION_PATCH_DIR}/ksu/susfs/susfs.sh"
        [ -f "$susfs_script" ] || error "SuSFS script not found: $(basename "$susfs_script")"
        echo "::group::🧬 SuSFS"
        source "$susfs_script" || error "SuSFS script failed: $(basename "$susfs_script")"
        echo "::endgroup::"
    fi
}

# ======================================================
# 🔧 CORE
# ======================================================

run_core() {
    echo "::group::🔧 Core"
    # Flat scripts first, then known subfolder orchestrators
    # Explicit list prevents accidental sourcing of temp/unrelated .sh files
    local core_dir="${SAGA_PATCH_DIR}/kernel/core"
    local scripts=(
        "${core_dir}/dirty_flag.sh"
        "${core_dir}/glibc.sh"
        "${core_dir}/protected_exports.sh"
        "${core_dir}/compiler_string/compiler_string.sh"
        "${core_dir}/module_bypass/module_bypass.sh"
        "${core_dir}/openssl3_compat/openssl3_compat.sh"
#       "${core_dir}/mm_stable_catchup/mm_stable_catchup.sh"
#       "${core_dir}/f2fs_thermal_catchup/f2fs_thermal_catchup.sh"
#       "${core_dir}/binder_cpufreq_catchup/binder_cpufreq_catchup.sh"
        "${core_dir}/ufs_writebooster_catchup/ufs_writebooster_catchup.sh"
        "${core_dir}/workqueue_catchup/workqueue_catchup.sh"
        "${core_dir}/schedutil_catchup/schedutil_catchup.sh"
        "${core_dir}/tickrate_choice/tickrate_choice.sh"
    )
    for script in "${scripts[@]}"; do
        [ -f "$script" ] || { warn "Core script not found: $(basename "$script") — skipping"; continue; }
        source "$script" || error "Core script failed: $(basename "$script")"
    done
    echo "::endgroup::"
}

# ======================================================
# ⚡ ADDONS
# ======================================================

run_addons() {
    # Populated below with only the addons that were actually found+sourced
    # (not the raw $ADDONS request) — run_postbuild() dispatches off this,
    # not off $ADDONS, so it never tries a postbuild step for a name that
    # never actually ran here (e.g. a typo'd addon, silently warned about
    # below instead of erroring).
    APPLIED_ADDONS=""
    [ -z "${ADDONS:-}" ] && return 0
    # Strip whitespace, leading/trailing commas, and duplicate commas
    ADDONS="${ADDONS// /}"
    ADDONS="$(echo "$ADDONS" | sed 's/^,*//;s/,*$//;s/,,*/,/g')"
    [ -z "${ADDONS}" ] && return 0
    echo "::group::⚡ Addons"
    # Conflict matrix — addons that patch overlapping kernel subsystems and
    # cannot be safely combined. Checked up front so a bad combo fails fast
    # instead of leaving a half-patched tree mid-build.
    if [[ ",${ADDONS}," == *,nomount,* ]] && [[ ",${ADDONS}," == *,zeromount,* ]]; then
        error "Addon conflict: 'nomount' and 'zeromount' both redirect VFS paths and cannot be combined — pick one."
    fi
    if [ "${KERNEL_VARIANT:-}" = "VANILLA" ]; then
        # Both zeromount and nomount exist to hide root/mount artifacts
        # from detection — meaningless on VANILLA, which has no root
        # solution at all to hide. Whatever the workflow_dispatch
        # mountless_engine input picked applies to every variant in the
        # matrix (see prepare-matrix in build.yml), so it can land here
        # too; rather than fall back from one to the other like the
        # SuSFS case below, VANILLA always builds with neither, full
        # stop — not "pick a different mountless engine", just none.
        for engine in zeromount nomount; do
            if [[ ",${ADDONS}," == *,${engine},* ]]; then
                warn "Addon skip: '${engine}' requested but this is a VANILLA build (no root solution to hide mounts for) — building with neither mountless engine"
                ADDONS="$(echo ",${ADDONS}," | sed "s/,${engine},/,/")"
                ADDONS="${ADDONS#,}"
                ADDONS="${ADDONS%,}"
            fi
        done
    elif [[ ",${ADDONS}," == *,zeromount,* ]] && [ "${SUSFS_ENABLED:-false}" != "true" ]; then
        # Rooted variant (RESUKISU/SUKISU/KSUNEXT), but this run has
        # susfs=false — zeromount's readdir.c/namei.c/task_mmu.c hooks are
        # SuSFS-baseline only, no non-SuSFS fallback inside zeromount
        # itself. There's still a real root solution to hide here (unlike
        # VANILLA above), so fall back to 'nomount' instead of dropping
        # the mountless engine outright. The nomount/zeromount mutual-
        # exclusion check above already covers both being requested
        # together explicitly.
        warn "Addon fallback: 'zeromount' requires SuSFS, not enabled for this variant (${KERNEL_VARIANT:-unknown}) — using 'nomount' instead for this build"
        ADDONS="${ADDONS//zeromount/nomount}"
    fi
    IFS=',' read -ra ADDON_LIST <<< "$ADDONS"

    for addon in "${ADDON_LIST[@]}"; do
        addon="${addon// /}"
        [ -z "$addon" ] && continue
        local script="${SAGA_PATCH_DIR}/kernel/addons/${addon}/${addon}.sh"
        if [ -f "$script" ]; then
            source "$script" || error "Addon failed: ${addon}"
            APPLIED_ADDONS="${APPLIED_ADDONS:+${APPLIED_ADDONS},}${addon}"
        else
            log "⚠️ Addon not found: ${addon}"
        fi
    done
    echo "::endgroup::"
}

# ======================================================
# 🏗️ BUILD
# ======================================================

run_build() {
    echo "::group::🏗️ Build Kernel (${BUILD_SYSTEM})"
    source "${SAGA_PATCH_DIR}/build/make.sh"
    echo "::endgroup::"
}

# ======================================================
# 🧩 POST-BUILD (per-addon)
# ======================================================
# Separate from run_addons()/run_build() on purpose: addons in run_addons()
# patch source/defconfig and get compiled as part of the single vmlinux
# build in run_build(). Some addons instead need work done AFTER run_build()
# finishes — e.g. Kasumi's out-of-tree LKM needs Module.symvers from the
# now-built kernel tree, which doesn't exist before that point.
#
# This is a thin dispatcher, same shape as run_build(): it doesn't know or
# care what any given addon's post-build step actually does (compile an
# LKM, whatever else some future addon needs) — it just runs
# kernel/addons/<name>/postbuild.sh for every enabled addon that has one.
# Addons without a postbuild.sh (the majority — anything patch/Kconfig-only)
# are silently skipped here, same gating as run_addons() (membership in
# $ADDONS), no separate per-addon "enabled" flag needed.

run_postbuild() {
    [ "${DRY_RUN:-false}" = "true" ] && return 0
    [ -z "${APPLIED_ADDONS:-}" ] && return 0

    echo "::group::🧩 Post-Build"

    IFS=',' read -ra ADDON_LIST <<< "$APPLIED_ADDONS"
    for addon in "${ADDON_LIST[@]}"; do
        addon="${addon// /}"
        [ -z "$addon" ] && continue

        script="${SAGA_PATCH_DIR}/kernel/addons/${addon}/postbuild.sh"
        [ -f "$script" ] || continue

        log "🧩 Post-build: ${addon}"
        source "$script" || error "Post-build step failed: ${addon}"
    done

    echo "::endgroup::"
}

# ======================================================
# 🚀 RELEASE
# ======================================================

run_release() {
    echo "::group::🚀 Release"
    source "${SAGA_PATCH_DIR}/release/anykernel.sh" || error "Release failed: anykernel.sh"
    source "${SAGA_PATCH_DIR}/release/telegram/telegram.sh"  || error "Release failed: telegram.sh"
    echo "::endgroup::"
}

main "$@"
