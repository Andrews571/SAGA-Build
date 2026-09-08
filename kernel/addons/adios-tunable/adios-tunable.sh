#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS genhd enforcer logging (optional, pos-adios)
# Patch de terceiros, nao-upstream, nao testado em build real.
# Depende do addon "adios" ja ter rodado antes (mesma ordem em ADDONS=).
# ======================================================
# A partir da v3.3.4-SAGA do addon "adios", TODO o conteudo que antes
# vivia aqui (sysfs/LM tunables: confianca do modelo, auto-escala de
# fila, decaimento auto-detectado, heuristica de classe de dispositivo,
# boost interativo, controlador de profundidade adaptativo) ja esta
# dentro do patch do addon "adios" -- nao existe mais nada pra "somar"
# aqui em cima daquilo. Este addon agora e so o bonus de logging do
# enforcer de scheduler padrao em block/genhd.c (0003), continua
# genuinamente opcional e sem relacao com o funcionamento do ADIOS em
# si -- so torna o enforcer visivel no dmesg/logcat.
#
# Corrigido nesta revisao: a versao anterior de 0003 tinha uma linha
# malformada (hunk -/+ grudado sem quebra de linha) que fazia o
# `patch --dry-run` falhar SEMPRE, silenciosamente engolido pelo
# fallback "nao-fatal" abaixo -- ou seja, esse logging nunca chegou a
# ser aplicado de fato em nenhum build ate agora. Ver o cabecalho do
# proprio 0003-genhd-enforcer-logging.patch pra detalhes.

GENHD_LOGGING_PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios-tunable/0003-genhd-enforcer-logging.patch"

# Exige que o adios.c ja exista e ja tenha sido patcheado pelo addon
# "adios" -- o patch de logging e incremental sobre o enforcer que o
# addon "adios" adiciona a block/genhd.c.
if ! grep -q "ADIOS_VERSION \"3.3.4-SAGA\"" "${KERNEL_SRC}/block/adios.c" 2>/dev/null; then
    error "ADIOS-TUNABLE: block/adios.c nao esta no estado esperado (rode o addon 'adios' antes deste na lista ADDONS=)"
fi

log "📦 Applying genhd enforcer logging patch (optional)..."
if [ -f "$GENHD_LOGGING_PATCH" ]; then
    if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$GENHD_LOGGING_PATCH" > /dev/null 2>&1; then
        log "GENHD-LOGGING: patch already applied, skipping."
    elif patch -p1 --fuzz=3 --dry-run --forward -d "$KERNEL_SRC" < "$GENHD_LOGGING_PATCH" > /dev/null 2>&1; then
        patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$GENHD_LOGGING_PATCH" \
            || error "GENHD-LOGGING: patch apply failed!"
        log "GENHD-LOGGING: patch applied ✅"
    else
        log "GENHD-LOGGING: nao bateu (fuzz/conflito) -- pulando, nao fatal, so perde o logging extra"
    fi
else
    log "GENHD-LOGGING: arquivo nao encontrado em ${GENHD_LOGGING_PATCH}, pulando (nao fatal)"
fi

log "genhd enforcer logging integrado ✅"
