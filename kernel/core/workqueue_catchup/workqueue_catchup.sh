#!/usr/bin/env bash

# ======================================================
# 🩹 CORE — workqueue stable catch-up (lote 5)
# ======================================================
# kernel/workqueue.c: 2 of 5 candidates applied (adapted), 3 not
# applicable — this tree predates the per-CPU pool_workqueue-for-unbound
# refactor (636b927eba5b) and the BH-workqueue feature both fixes/races
# depend on.
#
# Applied:
#   - release PENDING bit in __queue_work()'s drain/destroy reject path
#     (adapted: uses get_work_pool_id(), this tree's older API, instead
#     of the newer work_offq_data struct packer)
#   - fix false-positive workqueue stall reports on weakly-ordered
#     architectures (arm64 named explicitly upstream) — re-reads
#     watchdog_ts under pool->lock before declaring a real stall.
#     CONFIG_WQ_WATCHDOG=y confirmed active in gki_defconfig, so this
#     watchdog genuinely runs. Adapted: this tree calls the field
#     watchdog_ts, not last_progress_ts.
#
# Not applicable, feature absent (same refactor boundary,
# 636b927eba5b / enomem: label / WORK_OFFQ_BH, none present here):
#   - wq->cpu_pwq leak in alloc_and_link_pwqs() unbound error path
#   - dangling wq->pwqs list entries in the same error path
#   - spurious data race in __flush_work() (needs BH work items)

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/lote5_workqueue.patch"

log "🩹 Applying workqueue stable catch-up (lote 5)..."
cd "${KERNEL_SRC}"

if git apply --check --reverse "$PATCH_FILE" > /dev/null 2>&1; then
    log "workqueue stable catch-up: already applied, skipping."
elif git apply --check "$PATCH_FILE" > /dev/null 2>&1; then
    git apply "$PATCH_FILE" || error "workqueue stable catch-up: apply failed!"
    log "workqueue stable catch-up: applied ✅"
else
    error "workqueue stable catch-up: does not apply cleanly — kernel source may have changed since this was written, needs re-verification!"
fi

cd "${ROOT_DIR}"

log "workqueue stable catch-up integrated ✅"
