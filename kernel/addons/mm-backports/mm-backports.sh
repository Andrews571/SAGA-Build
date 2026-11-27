#!/usr/bin/env bash
# ADDON — mm-backports (SAGA): 3 backports pequenos do mainline (PSI x2 + rmap).
# Sem mudança de struct/KMI. Ver patch.py. STATUS: teste em aparelho pendente.
PATCHER="${SAGA_PATCH_DIR}/kernel/addons/mm-backports/patch.py"
[ -f "${KERNEL_SRC}/kernel/sched/psi.c" ] || { warn "psi.c not found, skipping mm-backports"; return 0; }
out=$(python3 "$PATCHER" "$KERNEL_SRC") ; rc=$?
echo "$out" | while read -r l; do log "mm-backports: $l"; done
[ $rc -eq 0 ] || error "mm-backports: patch script failed!"
