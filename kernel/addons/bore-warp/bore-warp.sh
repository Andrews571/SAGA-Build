#!/usr/bin/env bash

# ======================================================
# ⚡ ADDON — BORE-WARP (SAGA)
# ======================================================
# Extensão do BORE (kernel/addons/bore/): adiciona um mecanismo de
# preempção "hard" e limitada, inspirado (não portado -- reescrito do
# zero contra o fair.c real do 6.1) no "root bucket warp" do scheduler
# Clutch da Apple (apple-oss-distributions/xnu,
# doc/scheduler/sched_clutch_edge.md, iOS 27/WWDC 2026).
#
# O BORE já favorece tarefas "frescas" (baixo burst_penalty) de forma
# SUAVE, via vruntime -- mas ainda é uma comparação relativa: se a
# tarefa rodando também estiver com vruntime baixo, uma tarefa fresca
# pode perder a preempção e esperar o wakeup_gran (4ms) ou o próximo
# tick. O bore-warp adiciona uma segunda checagem, independente, que
# força a preempção quando a tarefa acordando é fresca (score BORE
# baixo) e a que está rodando é uma hog relativa (score bem maior) --
# só que com um cooldown por cfs_rq (uma "janela de warp" que se
# renova), pra não deixar uma enxurrada de wakeups (ex. pool de binder
# threads) encadear preempções sem parar.
#
# PRÉ-REQUISITO: precisa do addon BORE já aplicado (kernel/addons/bore)
# -- este patch só ativa código dentro de blocos `#ifdef
# CONFIG_SCHED_BORE`. Sem o BORE aplicado, o patch ainda aplica limpo,
# mas o novo código vira no-op (não compila nada, os #ifdef ficam
# falsos). Ordem recomendada no build: bore → bore-warp → reflex (essa
# foi a ordem testada; as 3 aplicam juntas sem conflito, tocam arquivos
# diferentes exceto onde já é esperado).
#
# DESLIGADO POR PADRÃO. Isso mexe no caminho mais quente do scheduler
# (toda decisão de preempção em wakeup) -- não faz sentido herdar isso
# silenciosamente só por ativar CONFIG_SCHED_BORE. Pra testar, ligar em
# runtime:
#   echo 1 > /proc/sys/kernel/sched_bore_warp_enabled
# E ajustar se quiser:
#   /proc/sys/kernel/sched_bore_warp_max_score   (default 2,  faixa 0-39)
#   /proc/sys/kernel/sched_bore_warp_us          (default 2000us, faixa 0-50000)
#
# NUNCA rodou em hardware. Validado só estruturalmente (aplica limpo
# em conjunto com bore+reflex, chaves/parênteses batem, sem colisão de
# símbolo). Testar em bancada com sched_bore_warp_enabled=0 primeiro
# (comportamento idêntico a sem este addon) antes de ligar de vez.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/bore-warp-android14-6.1.patch"

log "⚡ Applying BORE-WARP patch..."
cd "${KERNEL_SRC}"

if patch -p1 --fuzz=3 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "BORE-WARP: already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward < "$PATCH_FILE" || error "BORE-WARP: apply failed!"
    log "BORE-WARP: applied ✅"
else
    error "BORE-WARP: does not apply cleanly on top of BORE — verified clean against android14-6.1-live + bore-android14-6.1-v6.8.0.patch on $(date +%Y-%m-%d), needs re-verification!"
fi

cd "${ROOT_DIR}"

export BORE_WARP_ENABLED=true

log "BORE-WARP integrated ✅ (off by default via sysctl — sched_bore_warp_enabled=0 — enable manually to test; untested on real hardware)"
