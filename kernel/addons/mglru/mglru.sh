#!/usr/bin/env bash

# ======================================================
# 🧠 ADDON — MGLRU v2 (SAGA)
# ======================================================
# O kernel android14-6.1 já traz CONFIG_LRU_GEN, mas ROMs Oplus/ColorOS
# fazem `echo 0 > /sys/kernel/mm/lru_gen/enabled` em post-fs-data
# (init.oplus.nandswap.sh, ~11 s de boot) e o MGLRU fica desligado.
# A v1 forçava o CORE em toda escrita, inclusive nesse `echo 0`, no meio
# do init → bootloop. A v2 muda o QUANDO:
#   1) liga o MGLRU completo ('y' = CORE + o que o hardware aceitar;
#      no Dimensity 7300: 0x0003) 90 s depois do late_initcall;
#   2) ignora escrita numérica 0 do userspace (loga processo e pid);
#   3) 'n' continua desligando (e cancela a ativação tardia);
#   4) toda escrita em `enabled` vai para o dmesg ("saga-mglru: ...").
# Validado em aparelho (Poco X7, ColorOS): MGLRU ligado em runtime com
# pressão de memória sem travar; ver docs/CHANGELOG-MANUTENCAO.md.
# STATUS: o boot com este addon ainda precisa de teste em aparelho.

VMSCAN_C="${KERNEL_SRC}/mm/vmscan.c"
PATCHER="${SAGA_PATCH_DIR}/kernel/addons/mglru/patch.py"
[ -f "$VMSCAN_C" ] || { warn "mm/vmscan.c not found, skipping mglru"; return 0; }
grep -q "^static ssize_t store_enabled(struct kobject \*kobj," "$VMSCAN_C" \
    || { warn "store_enabled() not found in this kernel's shape — MGLRU doesn't exist here or its shape changed, skipping"; return 0; }
python3 "$PATCHER" "$VMSCAN_C"
rc=$?
if [ $rc -eq 0 ]; then
    log "mglru v2 (delayed enable + ignore userspace 0) applied ✅"
else
    error "mglru: patch script failed!"
fi
