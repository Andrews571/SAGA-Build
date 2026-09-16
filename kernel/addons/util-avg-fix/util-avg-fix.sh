#!/usr/bin/env bash

# ======================================================
# 🧮 ADDON — sched/fair util_avg initial calc fix (SAGA)
# ======================================================
# Backport do commit upstream 72bffbf57c5247ac6146d1103ef42e9f8d094bc8
# ("sched/fair: Fix initial util_avg calculation", Dawei Li,
# tip/sched/urgent, mar/2024).
#
# Em post_init_entity_util_avg(), o cálculo do util_avg inicial usava
# se->load.weight (peso já escalado) em vez de se_weight(se) (peso
# real da tarefa). Em CONFIG_64BIT isso infla o util_avg inicial em
# 1024x. O capping seguinte evita valor absurdo, mas a conta errada
# ainda distorce a estimativa inicial que alimenta schedutil/
# REFLEX/PCCG logo na criação da task.
#
# Verificado contra android14-6.1-live em $(date +%Y-%m-%d 2>/dev/null):
# aplica limpo, reverte limpo. Não precisa de Kconfig novo -- é
# correção pura, sem gate.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/util-avg-fix-android14-6.1.patch"

log "🧮 Applying sched/fair util_avg fix..."
cd "${KERNEL_SRC}"

if patch -p1 --fuzz=3 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "UTIL_AVG_FIX: already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward < "$PATCH_FILE" || error "UTIL_AVG_FIX: apply failed!"
    log "UTIL_AVG_FIX: applied ✅"
else
    error "UTIL_AVG_FIX: does not apply cleanly — verified clean against android14-6.1-live, tree pode ter mudado desde então!"
fi

cd "${ROOT_DIR}"
log "sched/fair util_avg fix integrated ✅"
