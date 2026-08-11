#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS Tunable LM (experimental, pos-adios)
# Patch de terceiros, nao-upstream, nao testado em build real.
# Depende do addon "adios" ja ter rodado antes (mesma ordem em ADDONS=).
# ======================================================
# Adiciona 5 sysfs novos ao ADIOS ja aplicado:
#   lm_block_size_threshold, lm_outlier_percentile, lm_interval_threshold_ms
#   lm_seed_read, lm_seed_write (persistencia do modelo entre boots)
# Ver o cabecalho do proprio .patch para detalhes/ressalvas.

ADIOS_TUNABLE_PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios-tunable/0002-adios-tunable-lm-and-persist-android.patch"

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

log "ADIOS tunable-LM sysfs (lm_block_size_threshold, lm_outlier_percentile, lm_interval_threshold_ms, lm_seed_read, lm_seed_write) integrated ✅"
