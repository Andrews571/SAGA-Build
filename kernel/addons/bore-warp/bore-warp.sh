#!/usr/bin/env bash

# ======================================================
# ⚡ ADDON — BORE-WARP (SAGA) — Cerebral Clutch component
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
# falsos). Ordem recomendada no build: bore → bore-warp → CC Governor
# (essa foi a ordem testada; aplicam juntas sem conflito).
#
# LIGADO POR PADRÃO (SAGA-Build). Isso é parte do sistema Cerebral
# Clutch: o bore-warp fornece o sinal bore_warp_fired que o CC Governor
# (kernel/addons/cc-governor/cc_governor.c) consome em
# cc_bore_warp_check() como um dos seus gatilhos de confirmação -- o
# sistema completo (ADIOS Clutch → clutch-signals → CC Governor) só faz
# sentido de ponta a ponta com ele ligado. Era desligado por padrão
# quando este addon existia isolado (mexe no caminho mais quente do
# scheduler, toda decisão de preempção em wakeup); com o CC Governor
# consumindo o sinal, o trade-off foi reavaliado. Desligar por
# dispositivo se causar problema:
#   echo 0 > /proc/sys/kernel/sched_bore_warp_enabled
# Outros ajustes:
#   /proc/sys/kernel/sched_bore_warp_max_score   (default 2,  faixa 0-39)
#   /proc/sys/kernel/sched_bore_warp_us          (default 2000us, faixa 0-50000)
#
# Ligado por padrão nesta integração. Antes de considerar estável, medir
# stat_bore_warp_confirmed em cc_governor sob uso real: se crescer em
# ordem de centenas por segundo durante uso normal, aumentar
# sched_bore_warp_us (hoje 2000us) para 4000-5000us e re-medir.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/bore-warp-android14-6.1.patch"

log "⚡ Applying BORE-WARP patch..."
cd "${KERNEL_SRC}"

# --fuzz=0: política do projeto após um incidente real no ADIOS onde
# --fuzz=3 aceitou silenciosamente um hunk com contexto deslocado, e o
# erro só apareceu no boot. Um patch que só aplica com fuzz>0 deve ser
# regenerado contra a árvore atual, não forçado com tolerância.
if patch -p1 --fuzz=0 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "BORE-WARP: already applied, skipping."
elif patch -p1 --fuzz=0 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=0 --forward < "$PATCH_FILE" || error "BORE-WARP: apply failed!"
    log "BORE-WARP: applied ✅"
else
    error "BORE-WARP: does not apply cleanly on top of BORE — verified clean (--fuzz=0) against android14-6.1-live + bore-android14-6.1-v6.8.0.patch on $(date +%Y-%m-%d), needs re-verification!"
fi

cd "${ROOT_DIR}"

export BORE_WARP_ENABLED=true

log "BORE-WARP integrated ✅ (enabled by default — Cerebral Clutch component; monitor cc_governor's stat_bore_warp_confirmed under real use)"
