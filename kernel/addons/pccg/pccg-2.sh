#!/usr/bin/env bash

# ======================================================
# ⚡ ADDON — PCCG / Pre CPU Clutch Governor (SAGA)
# ======================================================
# O irmão "vai tudo" do REFLEX (kernel/addons/reflex/): mesmo mecanismo
# de floor por idle-time, levado adiante em tudo que o Reflex foi
# deliberadamente cauteloso, inspirado (não portado -- tudo aqui é
# escrito do zero contra o cpufreq/scheduler real do 6.1) nos conceitos
# do scheduler Clutch/Edge da Apple (iOS 27,
# apple-oss-distributions/xnu, doc/scheduler/sched_clutch_edge.md):
#
#   - AUTO-SUFICIENTE: o gatilho principal ("essa CPU acabou de ficar
#     ocupada") é uma borda simples de rq->nr_running indo de 0 pra
#     não-zero -- não depende de BORE, NO_HZ, EAS ou qualquer outro
#     addon. Funciona sozinho num kernel 6.1 "pelado".
#   - REFORÇADO QUANDO DISPONÍVEL: se CONFIG_SCHED_BORE estiver
#     presente, usa também o burst_penalty do BORE como segundo
#     gatilho independente (mesma ideia que o Reflex já tinha).
#   - MAIS AGRESSIVO POR PADRÃO: salto de 100% (não 70% como no
#     Reflex) ao disparar.
#   - CIENTE DE CAPACIDADE: escala automaticamente o salto por cluster
#     via arch_scale_cpu_capacity() -- núcleo LITTLE ainda leva salto
#     quase cheio (o Hz absoluto é pequeno de qualquer jeito), núcleo
#     BIG/prime respeita o hispeed_freq_pct configurado sem exagero.
#
# NÃO inclui uma classe de escalonamento Clutch de verdade (EDF
# hierárquico por QoS bucket, thread-group scoring, placement tipo
# Edge entre clusters) -- isso é cirurgia de scheduler-core, fora de
# escopo pra um governor. Ver kernel/addons/bore-warp/ pro pedaço
# pequeno e deliberadamente desligado-por-padrão dessa ideia que FOI
# julgado seguro pra entrar.
#
# PRÉ-REQUISITO: nenhum, roda sozinho. Se BORE também estiver
# aplicado, aproveita automaticamente (via #ifdef CONFIG_SCHED_BORE).
# Convive com REFLEX e schedutil -- os 3 governors ficam disponíveis
# ao mesmo tempo, escolha via scaling_governor. Testado aplicando
# junto com bore + bore-warp + reflex, numa árvore limpa, sem
# conflito de arquivo nem de símbolo.
#
# Aparece no sistema como "pccg" em
# /sys/devices/system/cpu/cpufreq/policyN/scaling_available_governors
# e os tunáveis ficam em .../policyN/pccg/ (mesmos nomes do Reflex,
# mais wake_edge_boost, auto_capacity_scale e instant_trigger_pct).
#
# NUNCA rodou em hardware. Validado só estruturalmente (aplica limpo
# sozinho e junto com bore+bore-warp+reflex, chaves/parênteses batem,
# zero colisão de símbolo entre os 3 governors). Testar em bancada
# como as outras variantes antes de considerar default.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/pccg-android14-6.1.patch"

log "⚡ Applying PCCG patch..."
cd "${KERNEL_SRC}"

if patch -p1 --fuzz=3 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "PCCG: already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward < "$PATCH_FILE" || error "PCCG: apply failed!"
    log "PCCG: applied ✅"
else
    error "PCCG: does not apply cleanly — verified clean against android14-6.1-live (order-independent re: reflex/bore) on $(date +%Y-%m-%d), needs re-verification!"
fi

cd "${ROOT_DIR}"

# Liga o Kconfig direto no defconfig, mesmo mecanismo confiável do
# bore.sh -- não depende de nenhum bloco em defconfig.sh que alguém
# precise lembrar de colar. select CPU_FREQ_GOV_ATTR_SET e select
# IRQ_WORK já ficam resolvidos automaticamente pelo Kconfig (a entry
# CPU_FREQ_GOV_PCCG já faz esse select sozinha).
DEFCONFIG_FILE="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "^CONFIG_CPU_FREQ_GOV_PCCG=y" "$DEFCONFIG_FILE"; then
    cat >> "$DEFCONFIG_FILE" << 'EOF'
# PCCG cpufreq governor (SAGA)
CONFIG_CPU_FREQ_GOV_PCCG=y
EOF
    log "PCCG: CONFIG_CPU_FREQ_GOV_PCCG enabled ✅"
fi

log "PCCG integrated ✅ (self-sufficient, BORE-enhanced when present; untested on real hardware)"
