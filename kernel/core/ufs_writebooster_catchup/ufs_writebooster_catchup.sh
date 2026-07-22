#!/usr/bin/env bash

# ======================================================
# 🩹 CORE — UFS / WriteBooster stable catch-up (lote 4)
# ======================================================
# drivers/ufs/host/ufs-mediatek.c (2 clean + 3 adapted + confirmed 2
# already-fixed/not-applicable) + WriteBooster buffer resize feature and
# its 12-days-later fix (drivers/ufs/core/{ufshcd,ufs-sysfs}.c,
# include/ufs/{ufs,ufshcd}.h) + UFS 4.1 critical health event, ported
# onto this tree's older WB attribute API (no pm_qos_enable/
# wb_flush_threshold/rtc_update_ms sysfs nodes here — inserted the new
# attrs next to the wb_on/enable_wb_buf_flush nodes that DO exist
# instead).
#
# ufs-mediatek.c included:
#   - AHIT (auto-hibern8) timer moved to fixup_dev_quirks() (clean)
#   - unbalanced MCQ IRQ enable/disable fix (clean)
#   - shutdown/suspend race: reject suspend while hba->shutting_down
#   - PWM mode switch fix — PARTIAL: the pmc_via_fastauto SLOW_MODE
#     rejection and the ADAPT/NO_ADAPT-by-power-mode piece are in; the
#     third piece (desired_working_mode) doesn't apply — this tree's
#     power-negotiation API (ufshcd_get_pwr_dev_param(), older
#     ufs_dev_params without that field) predates the refactor that
#     introduced it
#   - device power control: prevent VCCQ/VCCQ2 entering LPM prematurely
#     (adapted to this tree's simpler ufs_mtk_init(), no phy_dev/
#     skip_phy structure here — added a forward declaration for
#     ufs_mtk_dev_vreg_set_lpm() since the call now happens earlier in
#     the file than its definition)
#
# Already confirmed fixed, nothing to do: vccqx NULL check.
# Not applicable, feature absent: MCQ per-CPU IRQ mapping OOB
#   (ufs_mtk_mcq_get_irq() doesn't exist in this tree's MCQ code yet).
# Skipped deliberately: VCC-on-delay quirk is hard-gated to IP_VER_MT6995
#   only — dead code on a Dimensity 7300 Ultra.
#
# WriteBooster (drivers/ufs/core/*, include/ufs/*):
#   - dynamic WB buffer resize (JESD220G): 3 new sysfs nodes
#     (wb_resize_enable, wb_resize_hint, wb_resize_status), new enums,
#     new struct fields (dev_info->ext_wb_sup, hba->critical_health_count
#     shares this batch's insertion point)
#   - the fix 12 days later: correct DEVICE_DESC_PARAM_EXT_WB_SUP offset
#     used to detect resize support (was reading the wrong descriptor
#     field entirely, so the feature silently never activated on real
#     devices) — applied cleanly on top of the feature above
#   - UFS 4.1 critical-health exception event + critical_health sysfs
#     counter — only activates if wspecversion >= 0x410; harmless no-op
#     otherwise (applies but stays dormant if the actual flash is UFS
#     3.1/4.0, which is more likely on a Dimensity 7300 Ultra — no way to
#     confirm the exact flash part from source alone)

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/lote4_ufs_writebooster.patch"

log "🩹 Applying UFS/WriteBooster stable catch-up (lote 4)..."
cd "${KERNEL_SRC}"

if git apply --check --reverse "$PATCH_FILE" > /dev/null 2>&1; then
    log "UFS/WriteBooster stable catch-up: already applied, skipping."
elif git apply --check "$PATCH_FILE" > /dev/null 2>&1; then
    git apply "$PATCH_FILE" || error "UFS/WriteBooster stable catch-up: apply failed!"
    log "UFS/WriteBooster stable catch-up: applied ✅"
else
    error "UFS/WriteBooster stable catch-up: does not apply cleanly — kernel source may have changed since this was written, needs re-verification!"
fi

cd "${ROOT_DIR}"

log "UFS/WriteBooster stable catch-up integrated ✅"
