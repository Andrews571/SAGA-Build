#!/usr/bin/env bash

# ======================================================
# 🩹 CORE — schedutil stable catch-up (lote 6)
# ======================================================
# kernel/sched/cpufreq_schedutil.c + kernel/sched/core.c: only bind the
# sugov kthread to specific CPUs when the driver actually requires it
# (policy->dvfs_possible_from_any_cpu == false); otherwise let it run
# anywhere via set_cpus_allowed_ptr(), and let userspace change its
# affinity freely (dl_task_check_affinity() early-out for the sugov
# task). Relevant for big.LITTLE: avoids waking a big core just to run
# the governor kthread when a little core could do it.
#
# Adapted from upstream: this tree predates the kernel/sched/core.c ->
# kernel/sched/syscalls.c split, so the dl_task_check_affinity() part of
# this fix was ported into core.c directly instead.
#
# Everything else investigated in this batch needed no action:
#   - thermal gov_power_allocator.c divvy_up_power(): not applicable —
#     this tree still uses the older parallel-array design
#     (weighted_req_power[] passed directly into divvy_up_power(), no
#     struct power_actor field mix-up possible by construction)
#   - thermal total_weight caching bug: not applicable, no cached field
#   - cpufreq_schedutil.c limits_changed/need_freq_update series (3
#     commits): already fully applied — READ_ONCE/WRITE_ONCE/smp_mb()
#     all present and paired correctly
#   - devfreq mtk-cci-devfreq.c sram_reg error pointer: already fixed,
#     IS_ERR_OR_NULL() already in use

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/lote6_schedutil.patch"

log "🩹 Applying schedutil stable catch-up (lote 6)..."
cd "${KERNEL_SRC}"

if git apply --check --reverse "$PATCH_FILE" > /dev/null 2>&1; then
    log "schedutil stable catch-up: already applied, skipping."
elif git apply --check "$PATCH_FILE" > /dev/null 2>&1; then
    git apply "$PATCH_FILE" || error "schedutil stable catch-up: apply failed!"
    log "schedutil stable catch-up: applied ✅"
else
    error "schedutil stable catch-up: does not apply cleanly — kernel source may have changed since this was written, needs re-verification!"
fi

cd "${ROOT_DIR}"

log "schedutil stable catch-up integrated ✅"
