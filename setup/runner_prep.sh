#!/usr/bin/env bash
# ======================================================
# 🧰 Runner prep — free disk, swap, wait-for-disk (Start-Build)
# ======================================================
# Usage: runner_prep.sh free-disk | swap | wait-disk
#
#  free-disk : moves the big preinstalled toolchains out of the way (instant
#              rename) and deletes them in the BACKGROUND (low I/O priority),
#              recording the PID so wait-disk can tell when it is done.
#  swap      : creates/enables the swap file, retrying on transient failures.
#  wait-disk : blocks ONLY if free space is below DISK_NEED_GB while the
#              background delete is still running (bounded by DISK_WAIT_SECS).
#              Normal case (enough space already) = no delay at all.
#
# Env (all optional): SWAP_SIZE_GB=12  SWAP_PATH=/mnt/swapfile  SWAP_ATTEMPTS=3
#   RETRY_SLEEP=3  DISK_NEED_GB=30  DISK_WAIT_SECS=240  FREE_DISK_PIDFILE=/tmp/free_disk.pid
#   SUDO (default "sudo"; set empty to run without sudo, used by tests)

set -uo pipefail

SUDO="${SUDO-sudo}"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-12}"
SWAP_PATH="${SWAP_PATH:-/mnt/swapfile}"
SWAP_ATTEMPTS="${SWAP_ATTEMPTS:-3}"
RETRY_SLEEP="${RETRY_SLEEP:-3}"
DISK_NEED_GB="${DISK_NEED_GB:-30}"
DISK_WAIT_SECS="${DISK_WAIT_SECS:-240}"
FREE_DISK_PIDFILE="${FREE_DISK_PIDFILE:-/tmp/free_disk.pid}"

free_disk() {
  $SUDO mv /usr/share/dotnet           /tmp/_trash_dotnet   2>/dev/null || true
  $SUDO mv /usr/local/lib/android      /tmp/_trash_android  2>/dev/null || true
  $SUDO mv /opt/ghc                    /tmp/_trash_ghc      2>/dev/null || true
  $SUDO mv /usr/lib/jvm                /tmp/_trash_jvm      2>/dev/null || true
  $SUDO mv /usr/share/swift            /tmp/_trash_swift    2>/dev/null || true
  $SUDO mv /usr/local/share/powershell /tmp/_trash_pwsh     2>/dev/null || true
  ( $SUDO nice -n 19 ionice -c 3 rm -rf \
      /tmp/_trash_dotnet /tmp/_trash_android /tmp/_trash_ghc \
      /tmp/_trash_jvm /tmp/_trash_swift /tmp/_trash_pwsh \
      /var/lib/docker /var/cache/snapd /home/linuxbrew ) &
  echo $! > "$FREE_DISK_PIDFILE"
  mkdir -p /dev/shm/ldcache
  echo "🧹 Background cleanup started (pid $(cat "$FREE_DISK_PIDFILE"))"
}

swap_once() {
  $SUDO swapoff "$SWAP_PATH" 2>/dev/null || true
  $SUDO rm -f "$SWAP_PATH" &&
  $SUDO fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_PATH" &&
  $SUDO chmod 600 "$SWAP_PATH" &&
  $SUDO mkswap "$SWAP_PATH" &&
  $SUDO swapon "$SWAP_PATH"
}

setup_swap() {
  # Was thejerrybao/setup-swap-space@v1 — that repo 404s now, so it is inline.
  local attempt=1
  while ! swap_once; do
    if [ "$attempt" -ge "$SWAP_ATTEMPTS" ]; then
      echo "::error title=Swap::could not enable ${SWAP_SIZE_GB}G swap at ${SWAP_PATH} after ${attempt} attempts"
      return 1
    fi
    echo "::warning::swap setup failed (attempt ${attempt}/${SWAP_ATTEMPTS}) — retrying"
    sleep $(( RETRY_SLEEP * attempt ))
    attempt=$(( attempt + 1 ))
  done
  [ "$attempt" -gt 1 ] && echo "swap ready after ${attempt} attempts"
  free -h
}

avail_gb() { df --output=avail -BG / 2>/dev/null | tail -1 | tr -dc '0-9'; }

wait_disk() {
  local pid="" waited=0 avail
  [ -f "$FREE_DISK_PIDFILE" ] && pid=$(cat "$FREE_DISK_PIDFILE")
  while :; do
    avail=$(avail_gb); avail="${avail:-0}"
    if [ "$avail" -ge "$DISK_NEED_GB" ]; then
      echo "💾 ${avail}G free (need ${DISK_NEED_GB}G) — continuing"; return 0
    fi
    if [ -z "$pid" ] || [ ! -d "/proc/${pid}" ]; then
      echo "💾 ${avail}G free; background cleanup finished — continuing"; return 0
    fi
    if [ "$waited" -ge "$DISK_WAIT_SECS" ]; then
      echo "::warning::only ${avail}G free after waiting ${waited}s for the background cleanup — continuing anyway"; return 0
    fi
    echo "⏳ ${avail}G free, waiting for background cleanup (need ${DISK_NEED_GB}G)..."
    sleep 5; waited=$(( waited + 5 ))
  done
}

main() {
  case "${1:-}" in
    free-disk) free_disk ;;
    swap)      setup_swap ;;
    wait-disk) wait_disk ;;
    *) echo "usage: $0 free-disk|swap|wait-disk" >&2; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
