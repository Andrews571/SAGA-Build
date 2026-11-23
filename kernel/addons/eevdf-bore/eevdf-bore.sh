#!/usr/bin/env bash

# ======================================================
# 🧬 ADDON — EEVDF + BORE 7.0 (SAGA)
# ======================================================
# Alternativa ao addon 'bore' (BORE sobre CFS). Traz para o
# android14-6.1 o núcleo EEVDF (nível mainline 6.6 + protect_slice /
# PREEMPT_SHORT / PLACE_REL_DEADLINE do 6.12) e, por cima, o BORE 7.0.0
# do firelzrd (que só existe para kernels com EEVDF).
#
# KMI-neutro: todo estado novo mora no padding ANDROID_KABI_RESERVE
#   sched_entity : slots 1-4 (deadline, min_deadline, vlag, slice+rel_deadline)
#   sched_rt_entity: slots 1-4 (estado por task do BORE); signal_struct: slot 1 (cache do grupo)
#   task_struct  : intocado (slots 6-8 pertencem ao patch sysvipc do SAGA)
#   cfs_rq       : avg_vruntime/avg_load trocam de lugar com last/skip
# sizeof/offsets de sched_entity, cfs_rq, rq e task_struct ficam idênticos
# (conferido com -fdump-record-layouts contra a base 6.1.190).
#
# Série (aplicada em ordem):
#   0001 infra EEVDF (avg_vruntime) + remoção dos buddies last/skip
#   0002 EEVDF nível 6.6 (pick_eevdf, place_entity/PLACE_LAG, rbtree aumentada)
#   0003 protect_slice, PREEMPT_SHORT, PLACE_REL_DEADLINE
#   0004 BORE 7.0.0 (+ sched_bore_topapp_discount / _smooth_boost do SAGA)
# NÃO incluído: delayed dequeue, custom slice (sched_setattr).
#
# INCOMPATÍVEL com os addons 'bore' e 'bore-warp' (campos antigos do
# BORE sobre CFS). O build falha cedo se vierem juntos.
#
# Hooks vendor (android_rvh_*): rvh_check_preempt_tick deixa de ser
# chamado (a função não existe mais no EEVDF). Os demais continuam.
#
# Sysctls (kernel.*): sched_bore, sched_burst_inherit_type,
# sched_burst_smoothness, sched_burst_penalty_offset,
# sched_burst_penalty_scale, sched_burst_cache_lifetime,
# sched_burst_protect_slice_lv, sched_credit_cap_us,
# sched_bore_topapp_discount, sched_bore_topapp_smooth_boost.
# debugfs: sched/min_base_slice_ns (base_slice = múltiplo do tick).
#
# STATUS: compilado (objetos do escalonador) — NÃO testado em boot.
# Teste em aparelho obrigatório; mantenha o zip anterior.

EEVDF_DIR="${SAGA_PATCH_DIR}/kernel/addons/eevdf-bore/patches"

if [[ ",${ADDONS:-}," == *,bore,* || ",${ADDONS:-}," == *,bore-warp,* ]]; then
    error "EEVDF-BORE: incompatível com os addons 'bore'/'bore-warp' — escolha um escalonador só."
fi

log "🧬 Applying EEVDF + BORE 7.0 series..."
cd "${KERNEL_SRC}"

shopt -s nullglob
PATCHES=("${EEVDF_DIR}"/[0-9][0-9][0-9][0-9]-*.patch)
shopt -u nullglob
[ "${#PATCHES[@]}" -gt 0 ] || error "EEVDF-BORE: nenhum patch encontrado em ${EEVDF_DIR}!"

# Idempotência: os patches da série se sobrepõem (0002 mexe em linhas do
# 0001 etc.), então "já aplicado" só se detecta pelo ÚLTIMO patch da série
# (se o 0004 reverte limpo, a série toda está na árvore).
LAST_PATCH="${PATCHES[${#PATCHES[@]}-1]}"
if patch -p1 --dry-run --reverse < "$LAST_PATCH" > /dev/null 2>&1; then
    log "EEVDF-BORE: série já aplicada, pulando."
else
    for p in "${PATCHES[@]}"; do
        name="$(basename "$p")"
        patch -p1 --dry-run --forward < "$p" > /dev/null 2>&1 \
            || error "EEVDF-BORE: ${name} não aplica limpo — árvore diferente da android14-6.1.190 verificada, ou série parcialmente aplicada!"
        patch -p1 --forward < "$p" > /dev/null || error "EEVDF-BORE: falha ao aplicar ${name}!"
        log "EEVDF-BORE: ${name} aplicado ✅"
    done
fi

find "${KERNEL_SRC}" -name "*.orig" -delete -o -name "*.rej" -print | head -5

DEFCONFIG_FILE="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "^CONFIG_SCHED_BORE=y" "$DEFCONFIG_FILE"; then
    cat >> "$DEFCONFIG_FILE" << 'EOT'
# EEVDF + BORE 7.0 (SAGA)
CONFIG_SCHED_BORE=y
EOT
    log "EEVDF-BORE: CONFIG_SCHED_BORE enabled ✅"
fi

cd "${ROOT_DIR}"
log "EEVDF + BORE 7.0 integrated ✅"

if [ -n "${GITHUB_ENV:-}" ]; then
    echo "BORE_VERSION=v7.0.0" >> "$GITHUB_ENV"
fi
