#!/usr/bin/env bash

# ======================================================
# 🩹 CORE — mm/ stable catch-up (v6.1.175 → v6.1.177)
# ======================================================
# Bundles 9 real upstream fixes cherry-picked from linux-6.1.y (gregkh/linux)
# that hadn't reached this kernel source yet, verified and (where needed)
# manually adapted against THIS tree's actual code structure — several of
# the raw upstream diffs did not apply as-is because this ACK lineage has
# already diverged in mm/damon/*.c and mm/vmscan.c.
#
# Included (see lote1_mm.patch):
#   1. mm/page_alloc.c    — clear page->private in free_pages_prepare()
#   2. mm/huge_memory.c   — update file RSS counter before folio_put()
#   3. mm/vmscan.c        — skip VM_SPECIAL vmas in lru_gen_look_around() (MGLRU)
#   4. mm/damon/core.c    — implement damon_kdamond_pid()
#   5. mm/damon/ops-common.c — call folio_test_lru() after folio_get()
#   6. mm/damon/core.c    — use time_in_range_open() for DAMOS quota window
#   7. mm/damon/core.c    — disallow time-quota setting zero esz
#   8. mm/damon/lru_sort.c — query live status instead of a stale cache
#      (adapted: this tree's lru_sort.c has no timer_fn/last_enabled
#      mechanism, so the fix was ported into enabled_store()/kdamond_pid
#      directly instead of the upstream timer-based shape)
#   9. mm/damon/reclaim.c — same fix as #8, same adaptation, applied to
#      DAMON_RECLAIM. This is the one that matters most for this kernel:
#      without it, if the kdamond ever dies from an internal error (bad
#      commit_inputs, allocation failure), DAMON_RECLAIM/LRU_SORT would
#      stay stuck "enabled" without a running kdamond until reboot.
#
# All 9 were tested with a real `git apply --check` (and, where that
# failed, hand-ported and re-verified) against this exact kernel source
# before being bundled here — not just inspected.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/lote1_mm.patch"

log "🩹 Applying mm/ stable catch-up (lote 1)..."
cd "${KERNEL_SRC}"

if git apply --check --reverse "$PATCH_FILE" > /dev/null 2>&1; then
    log "mm stable catch-up: already applied, skipping."
elif git apply --check "$PATCH_FILE" > /dev/null 2>&1; then
    git apply "$PATCH_FILE" || error "mm stable catch-up: apply failed!"
    log "mm stable catch-up: applied (9 fixes) ✅"
else
    error "mm stable catch-up: does not apply cleanly — kernel source may have changed since this was written, needs re-verification!"
fi

cd "${ROOT_DIR}"

log "mm/ stable catch-up integrated ✅"
