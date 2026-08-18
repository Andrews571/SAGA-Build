#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS Tunable LM (experimental, pos-adios)
# Patch de terceiros, nao-upstream, nao testado em build real.
# Depende do addon "adios" ja ter rodado antes (mesma ordem em ADDONS=).
# ======================================================
# 0002: adiciona sysfs novos ao ADIOS ja aplicado (confianca do modelo,
#   auto-escala de fila, decaimento auto-detectado, heuristica de
#   classe de dispositivo, boost interativo, controlador de profundidade
#   adaptativo, constantes do modelo de latencia tunaveis) + correcoes
#   de default (compliance_flags=0, batch_limit discard/other, etc).
# 0003: adiciona logging real ao enforcer de scheduler padrao do SAGA
#   (block/genhd.c) -- era completamente silencioso antes.
# Ver o cabecalho de cada .patch pra detalhes/ressalvas completas.

ADIOS_TUNABLE_PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios-tunable/0002-adios-tunable-lm-and-persist-android.patch"
GENHD_LOGGING_PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios-tunable/0003-genhd-enforcer-logging.patch"

log "📦 Applying ADIOS tunable-LM patch (experimental)..."
[ -f "$ADIOS_TUNABLE_PATCH" ] || error "ADIOS-TUNABLE: patch file not found at ${ADIOS_TUNABLE_PATCH}!"

# Exige que o adios.c ja exista e ja tenha sido patcheado pelo addon "adios" -
# senao o diff nao bate (esse patch eh incremental sobre o resultado dele).
if ! grep -q "ADIOS_VERSION \"3.2.0\"" "${KERNEL_SRC}/block/adios.c" 2>/dev/null; then
    error "ADIOS-TUNABLE: block/adios.c nao esta no estado esperado (rode o addon 'adios' antes deste na lista ADDONS=)"
fi

if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$ADIOS_TUNABLE_PATCH" > /dev/null 2>&1; then
    log "ADIOS-TUNABLE: patch already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward -d "$KERNEL_SRC" < "$ADIOS_TUNABLE_PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$ADIOS_TUNABLE_PATCH" \
        || error "ADIOS-TUNABLE: patch apply failed!"
    log "ADIOS-TUNABLE: patch applied ✅"
else
    error "ADIOS-TUNABLE: patch does not apply cleanly — conflict, or 'adios' addon ran with a different base than expected!"
fi

log "ADIOS tunable-LM sysfs integrated ✅"

# --- genhd.c enforcer logging (nao-fatal se nao bater) ---
log "📦 Applying genhd enforcer logging patch (experimental)..."
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

log "ADIOS tunable + genhd logging integrados ✅"
