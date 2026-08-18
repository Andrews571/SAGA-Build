#!/usr/bin/env bash

# ======================================================
# 🩹 CORE — mm/ stable catch-up (v6.1.175 → v6.1.177)
# ======================================================
# Re-verified 2026-08-13 against the real 6.1.180 live-staging tree
# (after the manual linux-stable upstream catch-up): 7 of the original 8
# fixes are now confirmed already present natively — same pattern as the
# page_alloc.c item already dropped in the note below. Trimmed to the
# ONE fix confirmed still missing. If this ever needs re-deriving from
# scratch, re-check against the current live-staging tree first — this
# batch has now had two rounds of "already native" attrition.
#
# Remaining (see lote1_mm.patch):
#   1. mm/damon/core.c — use time_in_range_open() for the DAMOS quota
#      reset-window check instead of time_after_eq(), which is unsafe
#      across a jiffies wraparound (charged_from + interval can overflow
#      and wrap past `jiffies`, making the window look like it never
#      closes). Low-frequency edge case (needs ~49 days of uptime at
#      HZ=250 to hit), but cheap and correct to carry.
#
# Confirmed already native as of this re-verify (dropped, no longer
# tracked here — re-derive from upstream if ever needed again):
#   - mm/huge_memory.c — file RSS counter update before folio_put()
#   - mm/vmscan.c — skip VM_SPECIAL vmas in lru_gen_look_around() (MGLRU)
#   - mm/damon/core.c — damon_kdamond_pid() implementation
#   - mm/damon/ops-common.c — folio_test_lru() ordering in damon_get_page()
#   - mm/damon/core.c — disallow zero esz in time-quota setting
#   - mm/damon/lru_sort.c, mm/damon/reclaim.c — live status query instead
#     of a stale cache for kdamond_pid (the DAMON_RECLAIM one was called
#     out as the fix that mattered most for this kernel — good news that
#     it's natively covered now, not something to lose track of)
#
# Dropped in an earlier pass: mm/page_alloc.c — "clear page->private in
# free_pages_prepare()" is now native on the SAGA-Kernel-6.1 tree
# (confirmed: `page->private = 0;` already present in free_pages_prepare(),
# just a few lines further down than this patch's original context —
# picked up by Google's own GKI sync at some point after this catch-up was
# first written against the chainonyourdoor tree, not something SAGA
# carried over). Re-verified 2026-08 against a fresh SAGA-Kernel-6.1 clone
# after migrating off chainonyourdoor's repo.
#
# All fixes were tested with a real `git apply --check` (and, where that
# failed, hand-verified against the tree directly — `git apply --reject`
# plus manually confirming each rejected hunk's intent is already present)
# — not just inspected.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/lote1_mm.patch"

log "🩹 Applying mm/ stable catch-up (lote 1)..."
cd "${KERNEL_SRC}"

if patch -p1 --fuzz=3 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "mm stable catch-up: already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward < "$PATCH_FILE" || error "mm stable catch-up: apply failed!"
    log "mm stable catch-up: applied (8 fixes) ✅"
else
    error "mm stable catch-up: does not apply cleanly — kernel source may have changed since this was written, needs re-verification!"
fi

cd "${ROOT_DIR}"

log "mm/ stable catch-up integrated ✅"
