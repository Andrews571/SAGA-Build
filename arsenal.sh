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

case "${KERNEL_VERSION}" in
  "5.10") ANDROID_VERSION="android13" ;;
  "5.15") ANDROID_VERSION="android13" ;;
  "6.1")  ANDROID_VERSION="android14" ;;
  "6.6")  ANDROID_VERSION="android15" ;;
  "6.12") ANDROID_VERSION="android16" ;;
  *) error "Unknown kernel version: ${KERNEL_VERSION}" ;;
esac

KERNEL_BRANCH="${ANDROID_VERSION}-${KERNEL_VERSION}-lts"
KLEAF_MANIFEST_BRANCH="common-${ANDROID_VERSION}-${KERNEL_VERSION}"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LUMINAIRE_PATCH_DIR="${ROOT_DIR}/Luminaire-Patch/common"

# ======================================================
# 🚀 MAIN
# ======================================================

main() {
    echo "========================================"
    echo "  ✨ Luminaire Arsenal — ${KERNEL_VERSION}"
    echo "  🖥️ CPU: $(nproc --all) cores"
    echo "  📅 $(date)"
    echo "========================================"

    clone_patch_repo
    run_setup
    mkdir -p "$KERNEL_DIR" "$OUT_DIR"
    run_download

    log "✅ Arsenal ready!"
}

# ======================================================
# 🌀 CLONE PATCH REPO
# ======================================================

clone_patch_repo() {
    echo "::group::🌀 Luminaire-Patch"
    if [ -d "${ROOT_DIR}/Luminaire-Patch/.git" ]; then
        log "Luminaire-Patch already exists, skipping clone."
    else
        log "Cloning Luminaire-Patch..."
        git clone --depth=1 \
            https://x-access-token:${PERSONAL_TOKEN}@github.com/chainonyourdoor/Luminaire-Patch.git \
            "${ROOT_DIR}/Luminaire-Patch"
    fi
    echo "::endgroup::"
}

# ======================================================
# 📦 SETUP
# ======================================================

run_setup() {
    echo "::group::📦 Setup"
    for script in "${LUMINAIRE_PATCH_DIR}/setup/"*.sh; do
        source "$script" || error "Setup failed: $(basename "$script")"
    done
    echo "::endgroup::"
}

# ======================================================
# 📥 DOWNLOAD
# ======================================================

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
