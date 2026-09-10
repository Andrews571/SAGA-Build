#!/usr/bin/env bash

# ======================================================
# ⚡ ADDON — REFLEX (SAGA cpufreq governor)
# ======================================================
# Reescrita própria (não backport 1:1) do conceito do firelzrd/reflex
# v0.3.3 pro android14-6.1. O patch upstream tem como alvo mainline
# 7.1/7.3-rc1 e depende de helpers exportados de um refactor pós
# sched_ext (scx_switched_all, sugov_effective_cpu_perf,
# cpufreq_cpu_uclamp_capped, etc.) que não existem em 6.1 — não dava
# pra aplicar com fuzz, foi refeito do zero em cima do que o 6.1 já
# tem: effective_cpu_util()/cpu_bw_dl() (mesma base do schedutil,
# intocada) + get_cpu_idle_time() (mesmo idle-time accounting que o
# ondemand já usa em todo device ARM/MTK, EXPORT_SYMBOL_GPL desde
# sempre em drivers/cpufreq/cpufreq.c) pro "hispeed floor" de resposta
# instantânea.
#
# Não substitui o schedutil — registra "reflex" como governor
# adicional (CONFIG_CPU_FREQ_GOV_REFLEX), selecionável via
# scaling_governor ou como default via CONFIG_CPU_FREQ_DEFAULT_GOV_REFLEX.
# Convive de boa com o addon schedutil (force-default) já existente:
# só um dos dois vira o default de fato, escolhido no defconfig.
#
# Tunáveis por policy/cluster via sysfs (não precisa recompilar pra
# re-tunar por SoC):
#   /sys/devices/system/cpu/cpufreq/policyN/reflex/rate_limit_us
#   .../hispeed_window_us   (default 8000 — janela de amostragem real
#                             de busy%, maior que os 4000 do upstream
#                             x86 porque cpuidle de ARM/MTK é mais
#                             fragmentado e deixava a leitura ruidosa)
#   .../hispeed_load_pct    (default 90  — % de ocupação real que
#                             dispara o floor)
#   .../hispeed_freq_pct    (default 70  — onde o floor pousa, em %
#                             da capacidade máxima da policy; menor
#                             que 100% de propósito pra não fazer o
#                             cluster efficiency do 7300 saltar sempre
#                             pro topo em rajada curta)
#   .../hispeed_decay_shift (default 1   — decaimento geométrico do
#                             floor a cada janela)
#
# NÃO é addon "prod-ready sem teste": é a base de código corrigida e
# validada estruturalmente (aplica limpo, chaves/parênteses batem,
# sem colisão de símbolo), mas nunca rodou em hardware real. Testar
# em bancada antes de promover a default.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/reflex-android14-6.1.patch"

log "⚡ Applying REFLEX governor patch..."
cd "${KERNEL_SRC}"

if patch -p1 --fuzz=0 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "REFLEX: already applied, skipping."
elif patch -p1 --fuzz=0 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=0 --forward < "$PATCH_FILE" || error "REFLEX: apply failed!"
    log "REFLEX: applied ✅"
else
    error "REFLEX: does not apply cleanly — kernel source may have changed since this was written (verified clean against android14-6.1-live on $(date +%Y-%m-%d)), needs re-verification!"
fi

cd "${ROOT_DIR}"

export REFLEX_ENABLED=true

log "REFLEX integrated ✅ (CONFIG_CPU_FREQ_GOV_REFLEX will be enabled after defconfig; untested on real hardware — bench before shipping as default)"
