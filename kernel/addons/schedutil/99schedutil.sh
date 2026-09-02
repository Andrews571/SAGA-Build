#!/system/bin/sh
# SAGA — force schedutil governor, late in boot.
#
# Confirmed on POCO X6 Pro / Dimensity 7300 Ultra: the MediaTek vendor
# HAL (vendor.mediatek.hardware.mtkpower) sets the cpufreq governor to
# a vendor-registered "sugov_ext" governor once, early in boot — before
# this script's trigger fires. Confirmed on-device this is a one-time
# assignment, not continuously re-enforced: a manual late write to
# scaling_governor survives screen on/off with no reassertion observed.
# So a late, one-time write here is sufficient — no watcher/daemon
# needed. Runs via Magisk/KernelSU's late_start service trigger, which
# fires well after mtkpower's own early-boot assignment.
#
# Install: copy to /data/adb/service.d/, chmod 755. (Re)apply after
# every reflash if not otherwise automated.

for gov in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
    echo schedutil > "$gov" 2>/dev/null
done
