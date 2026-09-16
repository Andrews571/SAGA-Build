#!/usr/bin/env bash

# ======================================================
# 🔒 ADDON — PM Wakelock Blocker (SAGA)
# ======================================================
# Bloqueador de wakelock nomeado, inspirado no Boeffla Wakelock
# Blocker (andip71) -- mas NÃO é port do driver original. O driver
# original (drivers/base/power/boeffla_wl_blocker.c, ~2019) foi
# escrito contra uma API de wakeup_source bem mais antiga; em vez de
# adaptar aquele código, este addon reimplementa a mesma ideia direto
# em cima da interface atual, kernel/power/wakelock.c (o
# /sys/power/wake_lock mainline, mesmo arquivo que o WildKernels já
# mexe pro add_timeout_wakelocks_globally.patch).
#
# ESCOPO -- IMPORTANTE: só enxerga wakeup sources criados via
# /sys/power/wake_lock (SystemSuspend HAL, alguns blobs de vendor,
# PowerManager wakelocks do estilo antigo). NÃO enxerga
# wakeup_source_register() direto de driver -- a maioria dos
# wakelocks de IRQ de modem/Wi-Fi/NFC passa por esse segundo caminho e
# fica fora do alcance deste bloqueador. Serve pra travar locks
# nomeados que ficam presos vindos de HAL/vendor/userspace, não pra
# IRQ de driver.
#
# USO: depois de aplicado, listar nomes de wakelock ativos com
#   cat /sys/power/wake_lock
# e bloquear um ou mais (separados por ';') com
#   echo "nome_do_lock;outro_lock" > /sys/power/wake_lock_blocker
#
# NUNCA rodou em hardware. Validado só estruturalmente (aplica limpo
# contra android14-6.1-live, chaves/parênteses batem, nenhum símbolo
# novo colide com bore/bore-warp/reflex/pccg/schedutil). Testar em
# bancada como as outras variantes antes de considerar default --
# principalmente confirmar que nenhum lock crítico do SystemSuspend
# HAL da MediaTek nesse device usa esse caminho pra algo que quebre
# se bloqueado por engano.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/pm-wakelock-blocker-android14-6.1.patch"

log "🔒 Applying PM Wakelock Blocker patch..."
cd "${KERNEL_SRC}"

if patch -p1 --fuzz=3 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "PM_WAKELOCK_BLOCKER: already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward < "$PATCH_FILE" || error "PM_WAKELOCK_BLOCKER: apply failed!"
    log "PM_WAKELOCK_BLOCKER: applied ✅"
else
    error "PM_WAKELOCK_BLOCKER: does not apply cleanly — verified clean against android14-6.1-live on $(date +%Y-%m-%d), needs re-verification!"
fi

cd "${ROOT_DIR}"

DEFCONFIG_FILE="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "^CONFIG_PM_WAKELOCK_BLOCKER=y" "$DEFCONFIG_FILE"; then
    cat >> "$DEFCONFIG_FILE" << 'EOF'
# PM Wakelock Blocker (SAGA)
CONFIG_PM_WAKELOCK_BLOCKER=y
EOF
    log "PM_WAKELOCK_BLOCKER: CONFIG_PM_WAKELOCK_BLOCKER enabled ✅"
fi

log "PM Wakelock Blocker integrated ✅ (só pega locks via /sys/power/wake_lock; untested on real hardware)"
