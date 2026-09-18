#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS Clutch (experimental variant of the default "adios")
# ======================================================
# MUTUALLY EXCLUSIVE com o addon "adios" -- os dois criam block/adios.c
# do zero (new-file patch) e registram o mesmo elevator_name "adios".
# NAO coloque os dois no ADDONS= ao mesmo tempo -- vai dar conflito de
# arquivo. Pra testar esta variante, troque "adios" por "adios-clutch"
# na lista, e troque de volta quando quiser voltar ao padrao.
#
# Base: v3.3.5-SAGA (mesma coisa que o addon "adios" tem hoje -- todas
# as correcoes das rodadas de review 1-4 ja incluidas). Em cima disso:
#
# - sideload_latency_model() agora reseta ad->aggr_buckets ela mesma,
#   sob o mesmo lock que ja protege esse campo -- antes, so 2 dos 5
#   pontos que chamam essa funcao resetavam aggr_buckets depois (e
#   fora do lock); os outros 3 nao resetavam nada.
# - 3 novos atributos sysfs, read-only, pensados pra serem lidos por
#   um consumidor externo (ex.: um governor de CPU), nao so por humano
#   debugando: in_flight_stats (count + total_pred_lat_ns),
#   confidence (small/large por optype), io_pressure (score 0-100).
#   Nenhum adiciona lock novo nem custo no hot path -- so expoem
#   estado que ja existia.
# - adios_version agora reporta "3.3.5-SAGA-Clutch" pra distinguir
#   essa variante da build padrao no sysfs.
#
# Analisados e decididos SEM mudar codigo (documentado no header do
# .patch): batch_limit auto-scale (sem dado de calibracao pra decidir
# um numero novo), assimetria do step (comentario ja existia),
# kfree_rcu sem check de NULL (macro ja trata NULL sozinho), pre-
# alocacao por tag pro rq_data (pool ja e dimensionado por
# q->nr_requests com free 1:1 em finish_request -- falha e
# estruturalmente inalcancavel em operacao normal, redesenho traria
# risco sem ganho real).

PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios-clutch/ADIOS_Clutch-Android-14-6.1.patch"

log "📦 Applying ADIOS Clutch patch (experimental variant)..."
[ -f "$PATCH" ] || error "ADIOS-CLUTCH: patch file not found at ${PATCH}!"

if patch -p1 --fuzz=0 --dry-run --reverse -d "$KERNEL_SRC" < "$PATCH" > /dev/null 2>&1; then
    log "ADIOS-CLUTCH: patch already applied, skipping."
elif patch -p1 --fuzz=0 --dry-run --forward -d "$KERNEL_SRC" < "$PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=0 --forward -d "$KERNEL_SRC" < "$PATCH" \
        || error "ADIOS-CLUTCH: patch apply failed!"
    log "ADIOS-CLUTCH: patch applied ✅"
else
    log "ADIOS-CLUTCH: dry-run failed — re-running for real (not suppressed) so the actual per-hunk diagnostic below shows what's wrong, instead of guessing:"
    patch -p1 --fuzz=0 --forward -d "$KERNEL_SRC" < "$PATCH"
    error "ADIOS-CLUTCH: patch does not apply cleanly at fuzz=0 — see the per-file/per-hunk output immediately above for exactly which file and which hunk failed. A leftover 'adios' folder in kernel/addons/ that ADDONS= doesn't reference is NOT the cause on its own — the log above is definitive, don't guess past it."
fi

DEFCONFIG_FILE="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "^CONFIG_MQ_IOSCHED_ADIOS=y" "$DEFCONFIG_FILE"; then
    cat >> "$DEFCONFIG_FILE" << 'DEFCONFIG_EOF'
# ADIOS I/O scheduler (SAGA Clutch variant)
CONFIG_MQ_IOSCHED_ADIOS=y
CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y
DEFCONFIG_EOF
    log "ADIOS-CLUTCH: CONFIG_MQ_IOSCHED_ADIOS + DEFAULT_ADIOS enabled ✅"
fi

log "ADIOS Clutch integrated ✅ — adios_version sysfs will report 3.3.5-SAGA-Clutch"
