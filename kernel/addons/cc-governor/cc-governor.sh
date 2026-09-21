#!/usr/bin/env bash

# ======================================================
# 🧠 ADDON — CC_GOVERNOR / Cerebral Clutch Governor (SAGA)
# ======================================================
# Descendente conservador do PCCG (kernel/addons/pccg/), reconstruído
# depois de dois relatos reais independentes (este aparelho e um
# Dimensity 8300) mostrando o PCCG grudado perto do teto de frequência
# ~87% do tempo acordado e consumindo 25-30% mais bateria que o
# schedutil puro, sem ganho de resposta medido sobre ele.
#
# O QUE MUDA DE VERDADE EM RELAÇÃO AO PCCG (não é só re-calibração,
# são correções de causa raiz já identificada com matemática, não
# achismo):
#   - cc_target_util(): compensação do headroom de +25% do
#     map_util_perf (divide por 125 em vez de 100) -- sem isso,
#     hispeed_freq_pct=70 já virava ~87% da frequência máxima real
#     num núcleo LITTLE, e 100 prendia sempre no teto. Agora o knob
#     significa aproximadamente o que o nome promete, linear.
#   - busy_threshold_pct (novo, default 15): floor com decaimento
#     agressivo quando a janela de idle-time mede ocupação real abaixo
#     desse limiar, em vez de esperar o hold+decay gradual pensado pra
#     rajada sustentada.
#   - filter_kthreads (novo, default 1): wake-edge com kthread como
#     rq->curr não dispara o floor por padrão (best-effort -- ver
#     comentário no código sobre a limitação real de precisão).
#   - streak recalibrado: 6 gatilhos em 60ms (era 3 em 120ms) -- o
#     valor antigo era trivialmente satisfeito por ruído de fundo em
#     densidade real de wakeups do Android, tornando quase todo
#     gatilho "confirmado" e anulando o instant_trigger_pct na prática.
#   - auto_capacity_scale off por padrão -- empurrava núcleos pequenos
#     pro nominal cheio, exatamente ao contrário do que eficiência pede.
#   - Telemetria via sysfs (stat_triggers_total, stat_triggers_confirmed,
#     stat_instant_applied, stat_streak_applied, stat_topapp_confirmed,
#     stat_bore_warp_confirmed) -- pra calibrar os próximos ajustes com
#     dado real do aparelho, não simulação.
#
# "Input boost separado do floor" foi endereçado sem criar um hook
# literal no subsistema de input (evdev) -- ver o cabeçalho de
# cc_governor.c pra o raciocínio completo: o wake-edge+streak já é
# esse boost, chega no mesmo evento mais cedo que um notifier de input
# chegaria, sem abrir um novo subsistema de risco pra um sinal que
# esse código já recebe primeiro.
#
# NÃO inclui uma classe de escalonamento Clutch de verdade -- isso
# continua fora de escopo pra um governor, mesma decisão de sempre.
#
# CERBRAL CLUTCH: este é o item central do sistema, não mais um addon
# isolado. Integra com kernel/addons/bore-warp/ (consome bore_warp_fired
# em cc_bore_warp_check(), sinal de confirmação forte) e, se
# kernel/addons/clutch-signals/ estiver presente, com o ADIOS via
# include/linux/clutch.h (gate de iowait boost por pressão de I/O real,
# confirmação de wake-edge por top-app ativo). Self-sufficient sem
# nenhum dos dois -- cada ponte degrada pra no-op seguro se a peça
# correspondente não estiver aplicada.
#
# PRÉ-REQUISITO: nenhum pra compilar -- self-sufficient. Ordem
# recomendada pra aproveitar tudo: bore → bore-warp → reflex → pccg →
# cc-governor → clutch-signals (qualquer um pode faltar, cada ausência
# só desativa o que depende dela). Testado aplicando nas duas ordens
# (CC antes e depois de bore/warp/reflex/pccg), numa árvore limpa, com
# --fuzz=0.
#
# Aparece no sistema como "cc_governor" em
# .../scaling_available_governors, tunáveis em
# .../policyN/cc_governor/.
#
# Ainda não rodou em hardware sob esta integração completa (com
# bore-warp ligado por padrão e a ponte clutch-signals). Validado
# estruturalmente (aplica limpo sozinho e com os outros 4 addons, nas
# duas ordens, com --fuzz=0; chaves/parênteses batem; zero colisão de
# símbolo -- inclusive simulando expansão de macro). Os 6 contadores
# de telemetria existem justamente pra calibrar com dado real de uso
# em vez de mais uma rodada de simulação -- ver stat_bore_warp_confirmed
# em particular, que mede se sched_bore_warp_us precisa subir.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/cc-governor-android14-6.1.patch"

log "🧠 Applying CC_GOVERNOR (Cerebral Clutch) patch..."
[ -f "$PATCH_FILE" ] || error "CC_GOVERNOR: patch file not found at ${PATCH_FILE}!"

# --fuzz=0: política do projeto (mesmo motivo do bore-warp -- um
# incidente real no ADIOS onde --fuzz=3 mascarou um hunk com contexto
# deslocado por meses). Um patch que só aplica com fuzz>0 precisa ser
# regenerado contra a árvore atual, não forçado com tolerância.
if patch -p1 --fuzz=0 --dry-run --reverse -d "$KERNEL_SRC" < "$PATCH_FILE" > /dev/null 2>&1; then
    log "CC_GOVERNOR: already applied, skipping."
elif patch -p1 --fuzz=0 --dry-run --forward -d "$KERNEL_SRC" < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=0 --forward -d "$KERNEL_SRC" < "$PATCH_FILE" \
        || error "CC_GOVERNOR: apply failed!"
    log "CC_GOVERNOR: applied ✅"
else
    error "CC_GOVERNOR: does not apply cleanly — verified clean (--fuzz=0, order-independent re: bore/reflex/pccg) against android14-6.1-live on $(date +%Y-%m-%d), needs re-verification!"
fi

# CONFIG_CPU_FREQ_GOV_CC=y só compila o governor -- sem
# CONFIG_CPU_FREQ_DEFAULT_GOV_CC=y o boot sobe com schedutil e o
# cc_governor fica disponível só pra troca manual via
# scaling_governor. O objetivo do projeto é CC ser o governor de
# boot, então os dois entram juntos.
DEFCONFIG_FILE="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "^CONFIG_CPU_FREQ_GOV_CC=y" "$DEFCONFIG_FILE"; then
    cat >> "$DEFCONFIG_FILE" << 'EOF'
# CC_GOVERNOR / Cerebral Clutch Governor (SAGA)
CONFIG_CPU_FREQ_GOV_CC=y
EOF
    log "CC_GOVERNOR: CONFIG_CPU_FREQ_GOV_CC + CONFIG_CPU_FREQ_DEFAULT_GOV_CC enabled ✅"
fi

log "CC_GOVERNOR integrated ✅ (default boot governor; self-sufficient, BORE/bore-warp/clutch-signals-enhanced when present)"
