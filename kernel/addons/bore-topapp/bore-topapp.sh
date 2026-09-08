#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — BORE Top-App Discount (experimental, pos-bore)
# Patch proprio (SAGA), nao-upstream, nao testado em build real ainda.
# Depende do addon "bore" ja ter rodado antes (mesma ordem em ADDONS=).
# ======================================================
# 0001: conecta o effective_prio() do BORE ao sinal que o proprio Android
#   ja expoe via cgroup (task_group(p)->latency_sensitive, setado pelo
#   ActivityManager/cpuset no cgroup top-app). Da um desconto tunavel
#   (sysctl kernel.sched_bore_topapp_discount, default 6, 0-39) no
#   burst_penalty efetivo de tarefas do app em foreground -- sem tocar
#   na logica comportamental do BORE em si.
# Ver o cabecalho do .patch pra racional completo e limites do desconto.

BORE_TOPAPP_PATCH="${SAGA_PATCH_DIR}/kernel/addons/bore-topapp/0001-bore-topapp-latency-sensitive-discount.patch"

log "📦 Applying BORE top-app discount patch (experimental)..."
[ -f "$BORE_TOPAPP_PATCH" ] || error "BORE-TOPAPP: patch file not found at ${BORE_TOPAPP_PATCH}!"

# Exige que fair.c ja tenha sido patcheado pelo addon "bore" -- senao o
# diff nao bate (este patch e incremental sobre o resultado dele).
if ! grep -q "sched_burst_cache_lifetime" "${KERNEL_SRC}/kernel/sched/fair.c" 2>/dev/null; then
    error "BORE-TOPAPP: kernel/sched/fair.c nao esta no estado esperado (rode o addon 'bore' antes deste na lista ADDONS=)"
fi

if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$BORE_TOPAPP_PATCH" > /dev/null 2>&1; then
    log "BORE-TOPAPP: patch already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward -d "$KERNEL_SRC" < "$BORE_TOPAPP_PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$BORE_TOPAPP_PATCH" \
        || error "BORE-TOPAPP: patch apply failed!"
    log "BORE-TOPAPP: patch applied ✅"
else
    error "BORE-TOPAPP: patch does not apply cleanly — conflict, or 'bore' addon ran with a different base than expected!"
fi

log "BORE top-app discount sysctl integrated ✅ (kernel.sched_bore_topapp_discount, default 6, tunavel em runtime)"
