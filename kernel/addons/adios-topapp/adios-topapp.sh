#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — ADIOS Top-App Deadline Bonus (experimental, pos-adios)
# Patch proprio (SAGA), nao-upstream.
# Depende do addon "adios" ja ter rodado antes, na VERSAO v3.3.4-SAGA
# (adios-android14-6.1-v3.3.4.patch). NAO aplica contra a v3.2.0 antiga.
# ======================================================
# 0003 (arquivo unico agora -- substitui os antigos 0003+0004 separados,
#   que foram construidos contra a base v3.2.0 e quebraram silenciosamente
#   quando o addon "adios" foi atualizado pra v3.3.4-SAGA):
#   - classifica requests por ioprio (RT ou BE nivel 0-1) e da um desconto
#     tunavel no deadline (sysfs topapp_deadline_bonus)
#   - o bonus nasce em 0 (desligado) e um timer proprio do ADIOS liga ele
#     sozinho, dentro do kernel, 90s depois de anexar na queue -- sem
#     init.rc, sem device tree, sem modulo

PATCH="${SAGA_PATCH_DIR}/kernel/addons/adios-topapp/0003-adios-topapp.patch"

log "📦 Applying ADIOS-TOPAPP patch..."
[ -f "$PATCH" ] || error "ADIOS-TOPAPP: patch file not found at ${PATCH}!"

# Version guard: this patch is pinned to v3.3.4-SAGA's block/adios.c.
# "shrink_work_fn" only exists from that merge onward -- if it's
# missing, the "adios" addon is still on the old v3.2.0 base (or was
# reverted to it), and applying this patch against it is exactly what
# caused the earlier silent-corruption bootloop. Fail loud instead.
if ! grep -q "shrink_work_fn" "${KERNEL_SRC}/block/adios.c" 2>/dev/null; then
    error "ADIOS-TOPAPP: block/adios.c does not look like v3.3.4-SAGA (missing shrink_work_fn) -- make sure the 'adios' addon is using adios-android14-6.1-v3.3.4.patch, not the old v3.2.0 file, before this addon runs"
fi

# fuzz=0 on purpose: a fuzzy/high-offset "success" against the wrong
# base is exactly what silently corrupted the last build. If this
# doesn't match byte-for-byte, fail loudly instead of guessing.
if patch -p1 --fuzz=0 --dry-run --reverse -d "$KERNEL_SRC" < "$PATCH" > /dev/null 2>&1; then
    log "ADIOS-TOPAPP: patch already applied, skipping."
elif patch -p1 --fuzz=0 --dry-run --forward -d "$KERNEL_SRC" < "$PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=0 --forward -d "$KERNEL_SRC" < "$PATCH" \
        || error "ADIOS-TOPAPP: patch apply failed!"
    log "ADIOS-TOPAPP: patch applied ✅"
else
    error "ADIOS-TOPAPP: patch does not apply cleanly at fuzz=0 -- block/adios.c has drifted from the exact v3.3.4-SAGA content this was verified against. Regenerate the patch against the current file instead of raising the fuzz level."
fi

log "ADIOS top-app deadline bonus integrated ✅ — starts DISABLED, self-activates via in-kernel timer ~90s after queue attach (kernel.topapp_activation_delay_ms to tune, no userspace/init changes needed)"
