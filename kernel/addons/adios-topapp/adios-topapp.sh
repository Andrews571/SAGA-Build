#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS Top-App Deadline Bonus (experimental, pos-adios)
# Patch proprio (SAGA), nao-upstream, nao testado em device real ainda.
# Depende do addon "adios" ja ter rodado antes (mesma ordem em ADDONS=).
# NAO verificado contra "adios-tunable" -- se usar os dois, cheque
# conflito em add_to_dl_tree()/struct adios_data antes de confiar.
# ======================================================
# 0003: da um desconto tunavel (sysfs topapp_deadline_bonus, default
#   4ms) no deadline de requests com ioprio elevado (RT, ou BE nivel
#   0-1), fazendo elas saírem mais cedo na arvore rb ordenada por
#   deadline. So tem efeito real se o seu task_profiles.json ja seta
#   ioprio pro cgroup top-app -- ver cabecalho do .patch pra como
#   checar isso no seu device antes de esperar resultado.

PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios-topapp/0003-adios-topapp-deadline-bonus.patch"

log "📦 Applying ADIOS top-app deadline-bonus patch (experimental)..."
[ -f "$PATCH" ] || error "ADIOS-TOPAPP: patch file not found at ${PATCH}!"

if ! grep -q "struct adios_data" "${KERNEL_SRC}/block/adios.c" 2>/dev/null; then
    error "ADIOS-TOPAPP: block/adios.c nao esta no estado esperado (rode o addon 'adios' antes deste na lista ADDONS=)"
fi

if patch -p1 --fuzz=3 --dry-run --reverse -d "$KERNEL_SRC" < "$PATCH" > /dev/null 2>&1; then
    log "ADIOS-TOPAPP: patch already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward -d "$KERNEL_SRC" < "$PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward -d "$KERNEL_SRC" < "$PATCH" \
        || error "ADIOS-TOPAPP: patch apply failed!"
    log "ADIOS-TOPAPP: patch applied ✅"
else
    error "ADIOS-TOPAPP: patch does not apply cleanly — conflict, or 'adios' addon ran with a different base than expected (e.g. adios-tunable also touched this file first)!"
fi

log "ADIOS top-app deadline bonus integrated ✅ (topapp_deadline_bonus sysfs, default 4ms — check ioprio is actually set for top-app on your device for this to have any effect)"
