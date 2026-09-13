#!/usr/bin/env bash

# ======================================================
# 🔥 ADDON — BORE (Burst-Oriented Response Enhancer)
# CPU scheduler by Masahito Suzuki (firelzrd)
# Repo: https://github.com/firelzrd/bore-scheduler
# ======================================================
# KABI-safe backport to v5.3.0-equivalent for android14-6.1: all BORE
# fields live inside struct sched_entity's existing
# ANDROID_KABI_RESERVE(1-4) slots (ANDROID_KABI_USE/_ANDROID_KABI_REPLACE),
# so sizeof(struct sched_entity) and every field offset after it stays
# identical to a non-BORE GKI build — no vendor-module KABI break.
#
# ATUALIZADO: este patch agora inclui, no mesmo arquivo, o que antes
# eram 3 addons separados -- bore-topapp (latency-sensitive discount) e
# bore-topapp-ideas (smooth-boost + fork-inherit discount). Gerado
# aplicando os 4 patches originais em sequência numa árvore limpa e
# tirando o diff acumulado -- nenhuma linha de comportamento mudou em
# relação aos 4 separados, é o mesmo resultado final.
#
# Por que juntar: o addon bore-warp (kernel/addons/bore-warp/) precisa
# saber o que já existe em kernel/sysctl.c pra não redefinir algo que o
# antigo bore-topapp já criava -- foi exatamente isso que quebrou um
# build (os dois patches definiam a constante 'thirty_nine' de forma
# independente, sem se conhecerem). Com tudo num arquivo só, qualquer
# addon novo é escrito em cima do estado real, sem esse tipo de atrito
# entre patches que não sabem da existência um do outro.
#
# REMOVIDO: as pastas kernel/addons/bore-topapp/ e
# kernel/addons/bore-topapp-ideas/ não devem mais constar na lista de
# ADDONS (o conteúdo delas já está aqui dentro). Aplicar os patches
# antigos junto com este vai duplicar tudo e falhar.
#
# Sysctls expostos (nomes e comportamento idênticos aos 3 addons de
# origem, nada mudou pra quem já usava):
#   sched_bore, sched_burst_inherit_type, sched_burst_smoothness,
#   sched_burst_penalty_offset, sched_burst_penalty_scale,
#   sched_burst_cache_lifetime                    (BORE base)
#   sched_bore_topapp_discount                    (topapp)
#   sched_bore_topapp_smooth_boost                (topapp-ideas: smooth-boost)
#   fork-inherit discount (sem sysctl próprio, reaproveita
#   sched_bore_topapp_discount)                   (topapp-ideas: fork-inherit)
#
# Testado: aplica limpo numa clonagem 100% fresca da android14-6.1-live.

BORE_PATCH="${SAGA_PATCH_DIR}/kernel/addons/bore/bore-android14-6.1-v6.8.0.patch"

log "🔥 Applying BORE CPU scheduler patch..."
[ -f "$BORE_PATCH" ] || error "BORE: patch file not found at ${BORE_PATCH}!"

if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$BORE_PATCH" > /dev/null 2>&1; then
    log "BORE: patch already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward -d "$KERNEL_SRC" < "$BORE_PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$BORE_PATCH" \
        || error "BORE: patch apply failed!"
    log "BORE: patch applied ✅"
else
    error "BORE: patch does not apply cleanly — conflict or unsupported kernel source!"
fi

# Limpa backups .orig que 'patch' pode gerar em hunks aplicados com fuzz
# (aconteceu ao gerar este patch; não custa garantir que não sobra lixo
# na árvore de build de vocês também).
find "${KERNEL_SRC}" -name "*.orig" -delete

DEFCONFIG_FILE="${KERNEL_SRC}/arch/arm64/configs/gki_defconfig"
if ! grep -q "^CONFIG_SCHED_BORE=y" "$DEFCONFIG_FILE"; then
    cat >> "$DEFCONFIG_FILE" << 'EOF'
# BORE CPU scheduler + topapp discount + topapp-ideas (SAGA)
CONFIG_SCHED_BORE=y
EOF
    log "BORE: CONFIG_SCHED_BORE enabled ✅"
fi

log "BORE CPU scheduler integrated ✅ (inclui topapp discount + topapp-ideas smooth-boost/fork-inherit)"

BORE_VERSION=$(basename "$BORE_PATCH" | sed -n 's/.*-\(v[0-9.]*\)\.patch$/\1/p')
if [ -n "$BORE_VERSION" ] && [ -n "${GITHUB_ENV:-}" ]; then
    echo "BORE_VERSION=${BORE_VERSION}" >> "$GITHUB_ENV"
fi
