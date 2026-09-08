#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — BORE Top-App Smooth Boost (experimental, pos-bore-topapp)
# Patch proprio (SAGA), nao-upstream, nao testado em device real ainda.
# Depende de "bore" e "bore-topapp" ja terem rodado, nessa ordem.
# ======================================================
# 0001: torna o crescimento do burst_penalty mais lento pra tarefas do
#   cgroup top-app (mesmo sinal do bore-topapp), via sysctl novo
#   kernel.sched_bore_topapp_smooth_boost (default 2, 0-8). So afeta o
#   ramp-up do penalty quando a tarefa piora; a recuperacao (penalty
#   caindo) ja e instantanea no BORE e continua assim.
# 0002: nao herda mais o "pior" burst penalty do grupo/irmaos quando o
#   processo recem-forkado ja nasce no cgroup top-app (cold-start de
#   app/thread nova). Reusa o sysctl sched_bore_topapp_discount que o
#   addon "bore-topapp" ja registrou.

apply_one() {
    local name="$1" patch="${SAGA_PATCH_DIR}/kernel/addons/bore-topapp-ideas/$2" grep_target="$3" grep_needle="$4"

    log "📦 Applying ${name} patch (experimental)..."
    [ -f "$patch" ] || error "${name}: patch file not found at ${patch}!"

    if ! grep -q "$grep_needle" "${KERNEL_SRC}/${grep_target}" 2>/dev/null; then
        error "${name}: ${grep_target} nao esta no estado esperado (rode 'bore' e 'bore-topapp' antes deste na lista ADDONS=)"
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

apply_one "BORE-TOPAPP-SMOOTH" "0001-bore-topapp-smooth-boost.patch" \
    "kernel/sched/fair.c" "sched_bore_topapp_discount"
apply_one "BORE-TOPAPP-FORK" "0002-bore-topapp-fork-inherit-discount.patch" \
    "kernel/sched/core.c" "sched_bore_topapp_discount"

log "BORE top-app ideas integrated ✅ (sched_bore_topapp_smooth_boost default 2, fork-inherit discount reusing sched_bore_topapp_discount)"
