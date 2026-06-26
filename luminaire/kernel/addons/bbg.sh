#!/usr/bin/env bash

log "Setting up Baseband Guard (BBG)..."
cd "${KERNEL_SRC}"
BBG_SETUP=$(curl -LSs --fail --retry 3 --connect-timeout 30 \
    "https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh") \
    || error "BBG: failed to download setup.sh!"
[ -n "$BBG_SETUP" ] || error "BBG: setup.sh is empty!"
echo "$BBG_SETUP" | grep -q "^#!" || error "BBG: setup.sh looks invalid (no shebang)!"
echo "$BBG_SETUP" | bash || error "BBG: setup.sh failed!"
[ -L "${KERNEL_SRC}/security/baseband-guard" ] \
    || error "BBG: inject failed — security/baseband-guard symlink not found!"

PATCHER="${LUMINAIRE_PATCH_DIR}/kernel/addons/bbg_kconfig_inject.py"
python3 "$PATCHER" "${KERNEL_SRC}/security/Kconfig" \
    || error "BBG: Kconfig inject failed!"

cd "${ROOT_DIR}"

log "Enabling CONFIG_BBG..."
if [ "$BUILD_SYSTEM" = "KLEAF" ]; then
    echo "CONFIG_BBG=y" >> "${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
else
    "${KERNEL_SRC}/scripts/config" --file "${OUT_DIR}/.config" --enable CONFIG_BBG
fi
log "BBG setup complete ✅"
