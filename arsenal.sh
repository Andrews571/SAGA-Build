#!/usr/bin/env bash
# ======================================================
# ✨ LUMINAIRE PROTOCOL — Arsenal Orchestrator
# ======================================================

set -eo pipefail

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# ======================================================
# ⚙️ CONFIGURATION
# ======================================================

KERNEL_VERSION="${KERNEL_VERSION:?KERNEL_VERSION is not set}"

ANDROID_VERSION="$(resolve_android_version)"
KERNEL_BRANCH="${ANDROID_VERSION}-${KERNEL_VERSION}-lts"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LUMINAIRE_PATCH_DIR="${ROOT_DIR}"

# ======================================================
# 🚀 MAIN
# ======================================================

main() {
    echo "========================================"
    echo "  ✨ Luminaire Arsenal — ${KERNEL_VERSION}"
    echo "  🖥️ CPU: $(nproc --all) cores"
    echo "  📅 $(date)"
    echo "========================================"

    run_setup
    mkdir -p "$KERNEL_DIR" "$OUT_DIR"
    run_download

    wait_for_apt

    log "✅ Arsenal ready!"
}


# ======================================================
# 📥 DOWNLOAD
# ======================================================
# (run_setup() is defined in functions.sh, shared with build.sh)

run_download() {
    echo "::group::📥 Arsenal Download"
    if [ "$BUILD_SYSTEM" = "KLEAF" ]; then
        source "${LUMINAIRE_PATCH_DIR}/download/kleaf.sh"
    else
        source "${LUMINAIRE_PATCH_DIR}/download/make.sh"
    fi
    log "Arsenal downloaded ✅"
    echo "::endgroup::"
}

main "$@"
