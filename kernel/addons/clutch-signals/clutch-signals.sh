#!/usr/bin/env bash

# ======================================================
# 📦 ADDON — Clutch Signals (bridge: ADIOS <-> CC governor)
# ======================================================
# Aplica ANTES de "adios-clutch" e de "cc-governor" -- os dois so
# fazem #include <linux/clutch.h> e chamam as funcoes, nao criam mais
# o header/arquivo de storage sozinhos (isso e exatamente o que
# causava "include/linux/clutch.h: already exists" quando os dois
# eram aplicados em sequencia antes desta mudanca).
#
# Fornece: include/linux/clutch.h (novo), kernel/sched/clutch.c (novo),
# CONFIG_CLUTCH_SIGNALS em block/Kconfig.iosched, e o
# obj-$(CONFIG_CLUTCH_SIGNALS) em kernel/sched/Makefile.
#
# Nao le nem escreve nada sozinho -- e so a infraestrutura
# compartilhada, os call sites vivem nos dois consumidores.

PATCH="${SAGA_PATCH_DIR}/kernel/addons/clutch-signals/clutch-signals-android14-6.1.patch"

log "📦 Applying Clutch Signals bridge patch..."
[ -f "$PATCH" ] || error "CLUTCH-SIGNALS: patch file not found at ${PATCH}!"

if patch -p1 --fuzz=0 --dry-run --reverse -d "$KERNEL_SRC" < "$PATCH" > /dev/null 2>&1; then
    log "CLUTCH-SIGNALS: patch already applied, skipping."
elif patch -p1 --fuzz=0 --dry-run --forward -d "$KERNEL_SRC" < "$PATCH" > /dev/null 2>&1; then
    patch -p1 --fuzz=0 --forward -d "$KERNEL_SRC" < "$PATCH" \
        || error "CLUTCH-SIGNALS: patch apply failed!"
    log "CLUTCH-SIGNALS: patch applied ✅"
else
    log "CLUTCH-SIGNALS: dry-run failed — re-running for real (not suppressed) so the actual per-hunk diagnostic below shows what's wrong, instead of guessing:"
    patch -p1 --fuzz=0 --forward -d "$KERNEL_SRC" < "$PATCH"
    error "CLUTCH-SIGNALS: patch does not apply cleanly at fuzz=0 — see the per-file/per-hunk output immediately above."
fi

log "Clutch Signals bridge integrated ✅ — adios-clutch and cc-governor must come AFTER this addon in ADDONS="
