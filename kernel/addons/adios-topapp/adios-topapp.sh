#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS Top-App Deadline Bonus (experimental, pos-adios)
# Patch proprio (SAGA), nao-upstream.
# Depende do addon "adios" ja ter rodado antes (mesma ordem em ADDONS=).
# NAO verificado contra "adios-tunable" -- se usar os dois, cheque
# conflito em add_to_dl_tree()/struct adios_data antes de confiar.
# ======================================================
# 0003: da um desconto tunavel (sysfs topapp_deadline_bonus) no deadline
#   de requests com ioprio elevado (RT, ou BE nivel 0-1), fazendo elas
#   saírem mais cedo na arvore rb ordenada por deadline.
# 0004: o bonus nasce em 0 (desligado) e um timer proprio do ADIOS
#   (mesmo padrao do update_timer que ja existe no arquivo) liga ele
#   sozinho, dentro do kernel, 90s depois de anexar na queue -- sem
#   init.rc, sem device tree, sem modulo. Tunavel via sysfs em runtime
#   (topapp_deadline_bonus_target, topapp_activation_delay_ms).

apply_one() {
    local name="$1" patch="${SAGA_PATCH_DIR}/kernel/addons/adios-topapp/$2" grep_needle="$3"

    log "📦 Applying ${name} patch..."
    [ -f "$patch" ] || error "${name}: patch file not found at ${patch}!"

    if ! grep -q "$grep_needle" "${KERNEL_SRC}/block/adios.c" 2>/dev/null; then
        error "${name}: block/adios.c nao esta no estado esperado (verifique a ordem dos addons anteriores)"
    fi

    if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$patch" > /dev/null 2>&1; then
        log "${name}: patch already applied, skipping."
    elif patch -p1 --fuzz=3 --dry-run --forward -d "$KERNEL_SRC" < "$patch" > /dev/null 2>&1; then
        patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$patch" \
            || error "${name}: patch apply failed!"
        log "${name}: patch applied ✅"
    else
        error "${name}: patch does not apply cleanly!"
    fi
}

apply_one "ADIOS-TOPAPP" "0003-adios-topapp-deadline-bonus.patch" "struct adios_data"
apply_one "ADIOS-TOPAPP-SELFTIMER" "0004-adios-topapp-self-activation-timer.patch" "adios_req_is_topapp"

log "ADIOS top-app deadline bonus integrated ✅ — starts DISABLED, self-activates via in-kernel timer ~90s after queue attach (kernel.topapp_activation_delay_ms to tune, no userspace/init changes needed)"
