#!/usr/bin/env bash

# ======================================================
# 📦 SETUP — APT DEPENDENCIES
# ======================================================

# Common — needed for both Make and Kleaf
PKGS_COMMON=(git curl wget zip patch rsync python3 ca-certificates aria2 pigz cpio g++ libzstd-dev)

# Make-only — Kleaf uses prebuilt toolchain, these are handled internally
PKGS_MAKE=(bc bison flex libssl-dev libelf-dev dwarves cmake ninja-build gcc-arm-linux-gnueabi)

if [ "$BUILD_SYSTEM" = "KLEAF" ]; then
    PKGS=("${PKGS_COMMON[@]}")
else
    PKGS=("${PKGS_COMMON[@]}" "${PKGS_MAKE[@]}")
fi

MISSING=()
for pkg in "${PKGS[@]}"; do
    dpkg -s "$pkg" &>/dev/null || MISSING+=("$pkg")
done

if [ ${#MISSING[@]} -gt 0 ]; then
    log "Installing missing packages: ${MISSING[*]}"
    if ls ~/.apt-cache/*.deb &>/dev/null 2>&1; then
        sudo cp -rn ~/.apt-cache/. /var/cache/apt/archives/ 2>/dev/null || true
    fi
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends "${MISSING[@]}" > /dev/null 2>&1
    mkdir -p ~/.apt-cache
    sudo cp /var/cache/apt/archives/*.deb ~/.apt-cache/ 2>/dev/null || true
    log "Dependencies installed ✅"
else
    log "All dependencies already installed ✅"
fi
