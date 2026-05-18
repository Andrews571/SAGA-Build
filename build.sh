#!/usr/bin/env bash
# ======================================================
# ✨ LUMINAIRE PROTOCOL
# GKI Kernel Build System — android14-6.1
# ======================================================

set -eo pipefail

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# ======================================================
# ⚙️ CONFIGURATION
# ======================================================

KERNEL_NAME="Luminaire"
BUILD_USER="chainonyourdoor"
BUILD_HOST="LuminaireCI"

KERNEL_REPO="https://github.com/chainonyourdoor/android_kernel_common-6.1"
KERNEL_BRANCH="android14-6.1-lts"
DEFCONFIG="gki_defconfig"
ARCH="arm64"

VARIANT="${VARIANT:-VANILLA}"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="${ROOT_DIR}/workspace"
CLANG_DIR="${ROOT_DIR}/greenforce-clang"
CLANG_BIN="${CLANG_DIR}/bin"
KERNEL_SRC="${WORK_DIR}/kernel"
AK3_DIR="${WORK_DIR}/AnyKernel3"
OUT_DIR="${WORK_DIR}/out"
PATCH_REPO="${ROOT_DIR}/Luminaire-Patch/android14-6.1-lts"

CCACHE_BIN="${ROOT_DIR}/ccache-bin/ccache"
CCACHE_WRAPPER_DIR="${ROOT_DIR}/ccache-wrappers"
export CCACHE_DIR="${CCACHE_DIR:-${ROOT_DIR}/.ccache}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"
export CCACHE_COMPRESS=1
export CCACHE_COMPRESSLEVEL=1

CLANG_CACHE_DIR="${HOME}/clang-cache"
KERNEL_CACHE_DIR="${HOME}/kernel-cache"

DATE=$(date +"%b%d")
ZIP_NAME="LuminaireProtocol-${DATE}R${GITHUB_RUN_NUMBER:-0}.zip"

LOG_FILE="/tmp/luminaire-$(date +%s).log"
touch "$LOG_FILE"

# ======================================================
# ⚡ CCACHE SETUP
# ======================================================
setup_ccache() {
    local CCACHE_HOME="${HOME}/ccache-bin"

    if [ ! -f "${CCACHE_HOME}/ccache" ]; then
        log "Building ccache-ECS from source..."
        sudo apt-get install -y --no-install-recommends \
            cmake ninja-build g++ libzstd-dev > /dev/null 2>&1
        git clone --depth=1 -b ccache-ECS-v1.0 \
            https://github.com/cctv18/ccache-ECS /tmp/ccache-ECS
        cmake -S /tmp/ccache-ECS -B /tmp/ccache-build \
            -GNinja -DCMAKE_BUILD_TYPE=Release \
            -DZSTD_FROM_INTERNET=OFF -DENABLE_TESTING=OFF \
            -DENABLE_DOCUMENTATION=OFF -DENABLE_IPO=ON \
            -DREDIS_STORAGE_BACKEND=OFF \
            -DHTTP_STORAGE_BACKEND=OFF > /dev/null 2>&1
        cmake --build /tmp/ccache-build -j$(nproc) > /dev/null 2>&1
        mkdir -p "${CCACHE_HOME}"
        cp /tmp/ccache-build/ccache "${CCACHE_HOME}/ccache"
        log "ccache-ECS built ✅"
    fi

    mkdir -p "${ROOT_DIR}/ccache-bin"
    cp "${CCACHE_HOME}/ccache" "${ROOT_DIR}/ccache-bin/ccache"
    chmod +x "${ROOT_DIR}/ccache-bin/ccache"

    log "Setting up ccache wrappers..."
    mkdir -p "$CCACHE_WRAPPER_DIR"
    for tool in clang clang++ clang-17 clang-18 clang-19 clang-20; do
        REAL_BIN="${CLANG_BIN}/${tool}"
        WRAPPER="${CCACHE_WRAPPER_DIR}/${tool}"
        if [ -f "$REAL_BIN" ]; then
            cat > "$WRAPPER" << WRAPPER_EOF
#!/usr/bin/env bash
exec "${CCACHE_BIN}" "${REAL_BIN}" "\$@"
WRAPPER_EOF
            chmod +x "$WRAPPER"
        fi
    done

    export PATH="${CCACHE_WRAPPER_DIR}:${PATH}"
    export CCACHE_COMPILER="${CLANG_BIN}/clang"
    export CCACHE_BASEDIR="$KERNEL_SRC"
    $CCACHE_BIN --zero-stats > /dev/null 2>&1 || true
    log "ccache ready | dir: ${CCACHE_DIR} | max: ${CCACHE_MAXSIZE}"
}

# ======================================================
# 🚀 MAIN
# ======================================================
main() {
    exec 1> >(tee -a "$LOG_FILE") 2>&1

    echo ""
    log "========================================"
    log "  ✨ Luminaire Protocol Build Start"
    log "  🖥️ CPU: $(nproc --all) cores"
    log "  💾 RAM: $(free -h | grep Mem | awk '{print $2}')"
    log "  📅 $(date)"
    log "========================================"
    echo ""

    mkdir -p "$WORK_DIR" "$OUT_DIR"

    # ======================================================
    # 📦 SETUP
    # ======================================================
    echo "::group::📦 Setup"

    log "Cloning Luminaire-Patch..."
    git clone --depth=1 \
        https://x-access-token:${PERSONAL_TOKEN}@github.com/chainonyourdoor/Luminaire-Patch.git \
        "${ROOT_DIR}/Luminaire-Patch"

    sudo apt-get install -y --no-install-recommends \
        bc bison flex libssl-dev libelf-dev dwarves \
        cpio git curl wget zip patch rsync > /dev/null 2>&1

    echo "::endgroup::"

    # ======================================================
    # 📥 KERNEL SOURCE
    # ======================================================
    echo "::group::📥 Kernel Source"

    if [ "${USE_KERNEL_CACHE:-false}" = "true" ] && [ -d "${KERNEL_CACHE_DIR}/arch" ]; then
        log "Restoring kernel source from cache..."
        cp -a "${KERNEL_CACHE_DIR}/." "${KERNEL_SRC}/"
        log "Kernel source restored ✅"
    else
        log "Cloning kernel source..."
        git clone -q --depth=1 \
            --filter=blob:limit=10M \
            -b "$KERNEL_BRANCH" \
            "$KERNEL_REPO" \
            "$KERNEL_SRC" || error "Failed to clone kernel!"
        log "Saving to cache..."
        mkdir -p "${KERNEL_CACHE_DIR}"
        rsync -a --exclude='.git' "${KERNEL_SRC}/" "${KERNEL_CACHE_DIR}/"
    fi

    SUBLEVEL="$(grep '^SUBLEVEL = ' "${KERNEL_SRC}/Makefile" | awk '{print $3}')"
    log "Kernel source ready ✅ (sublevel: ${SUBLEVEL})"
    echo "SUBLEVEL=${SUBLEVEL}" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true

    echo "::endgroup::"

    # ======================================================
    # 🧰 GREENFORCE CLANG
    # ======================================================
    echo "::group::🧰 Greenforce Clang"

    if [ "${USE_CLANG_CACHE:-false}" = "true" ] && [ -d "${CLANG_CACHE_DIR}/bin" ]; then
        log "Restoring Clang from cache..."
        cp -a "${CLANG_CACHE_DIR}/." "${CLANG_DIR}/"
        log "Clang restored ✅"
    else
        log "Downloading Greenforce Clang..."
        wget -qO- https://raw.githubusercontent.com/greenforce-project/greenforce_clang/refs/heads/main/get_clang.sh \
            | bash &> /dev/null
        [ ! -d "$CLANG_BIN" ] && error "Clang not found!"
        mkdir -p "${CLANG_CACHE_DIR}"
        cp -a "${CLANG_DIR}/." "${CLANG_CACHE_DIR}/"
        log "Clang saved to cache ✅"
    fi

    set +o pipefail
    CLANG_VER=$(${CLANG_BIN}/clang --version 2>&1 | head -1 || true)
    COMPILER_STRING=$(${CLANG_BIN}/clang -v 2>&1 | head -1 | sed 's/(https.*//' | sed 's/ version//' || true)
    set -o pipefail

    log "Clang ready: ${CLANG_VER}"
    echo "COMPILER_STRING=${COMPILER_STRING}" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true
    export PATH="${CLANG_BIN}:${PATH}"

    echo "::endgroup::"

    # ======================================================
    # ⚡ CCACHE
    # ======================================================
    echo "::group::⚡ Ccache"
    setup_ccache
    echo "::endgroup::"

    # ======================================================
    # 🔧 FIXES
    # ======================================================
    echo "::group::🔧 Fixes"
    for fix in "${PATCH_REPO}/fixes/"*.sh; do
        log "Applying: $(basename "$fix")..."
        source "$fix" || error "Fix failed: $(basename "$fix")"
    done
    log "All fixes applied ✅"
    echo "::endgroup::"

    # ======================================================
    # 🏗️ BUILD KERNEL
    # ======================================================
    echo "::group::🏗️ Build Kernel"

    export KBUILD_BUILD_USER="$BUILD_USER"
    export KBUILD_BUILD_HOST="$BUILD_HOST"
    export KBUILD_BUILD_TIMESTAMP="$(date)"
    export KCFLAGS="-w"

    SHORT_COMMIT="$(git -C "$KERNEL_SRC" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    LOCALVERSION="-${KERNEL_NAME}"
    touch "${KERNEL_SRC}/.scmversion"

    MAKE_ARGS=(
        -C "$KERNEL_SRC"
        O="$OUT_DIR"
        ARCH="$ARCH"
        CROSS_COMPILE=aarch64-linux-gnu-
        CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
        LLVM=1
        LLVM_IAS=1
        LOCALVERSION="$LOCALVERSION"
        -j"$(nproc --all)"
    )

    log "Generating defconfig..."
    make "${MAKE_ARGS[@]}" "$DEFCONFIG" || error "Defconfig failed!"

    log "Applying Luminaire configs..."
    source "${PATCH_REPO}/luminaire_defconfig.sh"

    log "Syncing config..."
    make "${MAKE_ARGS[@]}" olddefconfig || error "olddefconfig failed!"

    log "Building kernel..."
    START_TIME=$(date +%s)

    (
        set +eo pipefail
        while true; do
            sleep 30
            ELAPSED=$(( $(date +%s) - START_TIME ))
            printf "[LOG] Still building... ⏱️ %02d:%02d:%02d elapsed\n" \
                $((ELAPSED/3600)) $((ELAPSED%3600/60)) $((ELAPSED%60))
        done
    ) &
    HEARTBEAT_PID=$!

    make "${MAKE_ARGS[@]}" \
        || { kill "$HEARTBEAT_PID" 2>/dev/null; error "Build failed!"; }

    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true

    BUILD_SECONDS=$(( $(date +%s) - START_TIME ))
    log "Build completed in ${BUILD_SECONDS}s ✅"
    echo "BUILD_SECONDS=${BUILD_SECONDS}" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true

    echo "::endgroup::"

    # ======================================================
    # 📦 PACKAGE
    # ======================================================
    echo "::group::📦 Package AnyKernel3"

    if [ "${USE_AK3_CACHE:-false}" = "true" ] && [ -d "${HOME}/ak3-cache" ]; then
        cp -a "${HOME}/ak3-cache/." "${AK3_DIR}/"
        log "AnyKernel3 restored from cache ✅"
    else
        git clone -q --depth=1 \
            https://github.com/chainonyourdoor/AnyKernel3-Luminaire.git "$AK3_DIR" \
            || error "Failed to clone AK3!"
        mkdir -p "${HOME}/ak3-cache"
        cp -a "${AK3_DIR}/." "${HOME}/ak3-cache/"
    fi

    KERNEL_IMG=""
    for img in Image Image.gz Image.gz-dtb Image-dtb; do
        BOOT_PATH="${OUT_DIR}/arch/${ARCH}/boot/${img}"
        if [ -f "$BOOT_PATH" ]; then
            KERNEL_IMG="$BOOT_PATH"
            log "Kernel image: $img"
            break
        fi
    done
    [ -z "$KERNEL_IMG" ] && error "Kernel image not found!"

    cp "$KERNEL_IMG" "${AK3_DIR}/"

    ZIP_PATH="/tmp/${ZIP_NAME}"
    cd "$AK3_DIR"
    zip -r9 "$ZIP_PATH" . -x "*.git*" -x "*.github*" -x "*.md" -x "LICENSE"
    cd "$ROOT_DIR"

    log "ZIP ready: ${ZIP_NAME} ✅"
    echo "ZIP_NAME=${ZIP_NAME}" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true
    echo "ZIP_PATH=${ZIP_PATH}" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true

    echo "::endgroup::"

    # ======================================================
    # 📲 TELEGRAM
    # ======================================================
    echo "::group::📲 Telegram"

    LINUX_VERSION=$(make -C "$KERNEL_SRC" kernelversion 2>/dev/null | \
        grep -v "make" | head -n 1 | tr -d '[:space:]' || true)

    if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ] && [ -f "${ZIP_PATH:-}" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
            -F "chat_id=${TELEGRAM_CHAT_ID}" \
            ${TELEGRAM_THREAD_ID_BUILD:+-F "message_thread_id=${TELEGRAM_THREAD_ID_BUILD}"} \
            -F "document=@${ZIP_PATH};filename=${ZIP_NAME}" \
            -F "caption=✨ <b>Luminaire Protocol</b>
Linux     : ${LINUX_VERSION:-N/A}
Compiler  : ${COMPILER_STRING:-N/A}
Date      : $(date +'%d %b %Y')" \
            -F "parse_mode=HTML" || true
    fi

    echo "::endgroup::"

    echo ""
    log "========================================"
    log "  ✅ Build Complete! — ${ZIP_NAME}"
    log "========================================"
    echo ""
}

cleanup() {
    if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        CAPTION="📄 Build Log"
        [ -n "${BUILD_SECONDS:-}" ] && \
            CAPTION="✅ ${BUILD_SECONDS}s | 📦 ${ZIP_NAME:-unknown}"
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
            -F "chat_id=${TELEGRAM_CHAT_ID}" \
            ${TELEGRAM_THREAD_ID_LOG:+-F "message_thread_id=${TELEGRAM_THREAD_ID_LOG}"} \
            -F "document=@${LOG_FILE};filename=build-$(date +%Y%m%d-%H%M).log" \
            -F "caption=${CAPTION}" || true
    fi
}
trap cleanup EXIT

main "$@"
