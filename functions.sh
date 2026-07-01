#!/usr/bin/env bash

# ==================
# 🔧 FUNCTIONS
# ==================

COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'

log() {
  echo -e "${COLOR_CYAN}[LOG]${COLOR_RESET} $*"
}

warn() {
  echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

error() {
  echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"
  exit 1
}

# Runs a command, capturing combined stdout+stderr to a temp file.
# Silent on success. On failure, prints the last 50 lines so the
# real underlying error is visible instead of a blank failure.
run_quiet() {
    local logfile rc
    logfile="$(mktemp)"
    if "$@" > "$logfile" 2>&1; then
        rm -f "$logfile"
        return 0
    fi
    rc=$?
    echo -e "${COLOR_YELLOW}---- command output (last 50 lines) ----${COLOR_RESET}"
    tail -n 50 "$logfile"
    echo -e "${COLOR_YELLOW}-----------------------------------------${COLOR_RESET}"
    rm -f "$logfile"
    return "$rc"
}

# Maps KERNEL_VERSION (e.g. "6.1") to its ANDROID_VERSION branch prefix
# (e.g. "android14"). Shared by build.sh and arsenal.sh so the version
# table only needs updating in one place when a new kernel is added.
resolve_android_version() {
    case "${KERNEL_VERSION}" in
        "5.10") echo "android13" ;;
        "5.15") echo "android13" ;;
        "6.1")  echo "android14" ;;
        "6.6")  echo "android15" ;;
        "6.12") echo "android16" ;;
        *) error "Unknown kernel version: ${KERNEL_VERSION}" ;;
    esac
}

# Sources every *.sh in setup/, in order. Shared by build.sh and arsenal.sh.
run_setup() {
    echo "::group::📦 Setup"
    for script in "${LUMINAIRE_PATCH_DIR}/setup/"*.sh; do
        source "$script" || error "Setup failed: $(basename "$script")"
    done
    echo "::endgroup::"
}

# Waits for the background apt install kicked off by setup/01_deps.sh
# (APT_PID). Shared by build.sh and arsenal.sh so a fresh runner never
# proceeds into ccache/build steps before required packages land.
wait_for_apt() {
    if [ -n "${APT_PID:-}" ]; then
        log "Waiting for background apt install (PID ${APT_PID})..."
        if wait "$APT_PID"; then
            mkdir -p ~/.apt-cache
            sudo cp /var/cache/apt/archives/*.deb ~/.apt-cache/ 2>/dev/null || true
            log "Dependencies installed ✅"
        else
            error "Background apt install failed!"
        fi
    fi
}

# Retries a command with exponential backoff.
# Usage: retry <max_attempts> <command...>
retry() {
    local max_attempts="$1"; shift
    local attempt=1 delay=5 rc=0
    while true; do
        if "$@"; then
            return 0
        fi
        rc=$?
        if [ "$attempt" -ge "$max_attempts" ]; then
            return "$rc"
        fi
        warn "Attempt ${attempt}/${max_attempts} failed — retrying in ${delay}s..."
        sleep "$delay"
        delay=$(( delay * 2 ))
        attempt=$(( attempt + 1 ))
    done
}
