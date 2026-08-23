#!/usr/bin/env bash

# ======================================================
# ⚙️  ADDON — SCHEDUTIL (force default governor)
# ======================================================
# schedutil is ALREADY the compile-time default governor on this kernel
# (confirmed: drivers/cpufreq/Kconfig's "Default CPUFreq governor" choice
# defaults to CPU_FREQ_DEFAULT_GOV_SCHEDUTIL for ARM64, and nothing in
# saga.fragment overrides that choice — CONFIG_CPU_FREQ_GOV_ONDEMAND=y
# there only makes ondemand available as an alternative, it doesn't
# change the default). So this addon isn't "add schedutil" — it's
# "defend the default", the same category of problem as the ZRAM
# comp_algorithm race kernel/addons/lz4kd/lz4kd.sh already fixed:
# a vendor init.rc/HAL script can write a different scaling_governor
# during boot, and on a stock kernel that override then becomes the new
# policy->last_governor — which cpufreq_init_policy() faithfully restores
# on every subsequent CPU hotplug or suspend/resume cycle, making the
# override effectively permanent even though the kernel's own default
# was never touched.
#
# What this patch does (drivers/cpufreq/cpufreq.c, cpufreq_init_policy):
# behind a new CONFIG_SAGA_FORCE_SCHEDUTIL Kconfig bool, skip the
# last_governor restore path entirely and always re-apply the
# compile-time default governor instead — on boot, every hotplug, and
# every resume.
#
# What it deliberately does NOT do: block a live scaling_governor sysfs
# write to a policy that stays online the whole time (a kernel manager
# app, or a HAL that writes without ever offlining the CPU). That would
# need patching cpufreq_set_policy()/store_scaling_governor() itself to
# reject writes, which would also break legitimate manual governor
# switching — a real capability trade-off, not something to remove
# silently as a side effect of a "make schedutil stick" toggle. If the
# MTK HAL on this device turns out to override via a live write instead
# of an early-boot one-shot, this addon won't be enough on its own.

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/schedutil-android14-6.1.patch"

log "⚙️ Applying SCHEDUTIL force-default patch..."
cd "${KERNEL_SRC}"

if patch -p1 --fuzz=3 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "SCHEDUTIL: already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward < "$PATCH_FILE" || error "SCHEDUTIL: apply failed!"
    log "SCHEDUTIL: applied ✅"
else
    error "SCHEDUTIL: does not apply cleanly — kernel source may have changed since this was written, needs re-verification!"
fi

cd "${ROOT_DIR}"

export SCHEDUTIL_ENABLED=true

log "SCHEDUTIL force-default integrated ✅ (CONFIG_SAGA_FORCE_SCHEDUTIL will be enabled after defconfig)"
