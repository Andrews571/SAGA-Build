#!/usr/bin/env bash
# SAGA-Build addon: clutch-signals
# Shared, neutral bridge storage between ADIOS (I/O) and CC governor
# (CPU), plus the memory-pressure signal written by the memory
# subsystem. Must be applied BEFORE adios-clutch and cc-governor.
set -euo pipefail

# Resolve to an ABSOLUTE path now, before any cd below -- BASH_SOURCE
# can be relative (e.g. invoked as "kernel/addons/clutch-signals/clutch-signals.sh"
# from the SAGA-Build workspace root), and once we cd into the kernel
# source root further down, a relative PATCH_FILE would point at the
# wrong place (or nowhere).
ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${ADDON_DIR}/clutch-signals-android14-6.1.patch"

# SAGA: this addon used to assume it was invoked with the kernel source
# tree as cwd. In CI that assumption was false -- the generic addon
# loop runs addon scripts from a different working directory than the
# hardcoded, inline patch steps (BBRv3/BBG/BORE/BORE-WARP) further up
# in build.sh. Symptom was "can't find file to patch" on exactly the
# two hunks that modify EXISTING files (block/Kconfig.iosched,
# kernel/sched/Makefile), while the two that CREATE new files
# (include/linux/clutch.h, kernel/sched/clutch.c) silently "succeeded"
# in dry-run, since patch doesn't need an existing target to approve
# creating a new one -- it just masked the real cwd problem. Fix: find
# the actual kernel root ourselves instead of trusting cwd.
#
# Priority: respect an explicit KERNEL_DIR/KERNEL_SRC_DIR if the caller
# sets one; otherwise search upward from PWD, then a couple of likely
# sibling locations, for a directory that actually has both files this
# patch needs to modify.
find_kernel_root() {
	local candidate

	for candidate in "${KERNEL_DIR:-}" "${KERNEL_SRC_DIR:-}"; do
		if [ -n "${candidate}" ] && [ -f "${candidate}/block/Kconfig.iosched" ] && [ -f "${candidate}/kernel/sched/Makefile" ]; then
			echo "${candidate}"
			return 0
		fi
	done

	candidate="$(pwd)"
	while [ "${candidate}" != "/" ]; do
		if [ -f "${candidate}/block/Kconfig.iosched" ] && [ -f "${candidate}/kernel/sched/Makefile" ]; then
			echo "${candidate}"
			return 0
		fi
		candidate="$(dirname "${candidate}")"
	done

	# Known SAGA-Build layout: the real kernel source (Android Common
	# Kernel checkout) lives UNDER the workspace root, not beside it --
	# confirmed from a real CI run: SAGA_BUILD_ROOT/workspace/kernel/common
	# (the "Baseband-guard" addon clones into
	# .../workspace/kernel/common/Baseband-guard, which pins this down).
	# Also try a couple of nearby variants in case the layout drifts.
	for candidate in \
		"$(pwd)/workspace/kernel/common" \
		"$(pwd)/workspace/common" \
		"$(pwd)/workspace/kernel" \
		"$(pwd)/kernel/common" \
		"$(pwd)/common" \
		"$(pwd)/../common" \
		"$(pwd)/kernel_source" \
		"$(pwd)/../kernel_source"; do
		if [ -f "${candidate}/block/Kconfig.iosched" ] && [ -f "${candidate}/kernel/sched/Makefile" ]; then
			(cd "${candidate}" && pwd)
			return 0
		fi
	done

	# Last resort: bounded search a few levels down from cwd for the
	# anchor file. Depth-limited so this stays fast in a large workspace.
	candidate="$(find "$(pwd)" -maxdepth 5 -path '*/block/Kconfig.iosched' 2>/dev/null | head -1)"
	if [ -n "${candidate}" ]; then
		candidate="$(dirname "$(dirname "${candidate}")")"
		if [ -f "${candidate}/kernel/sched/Makefile" ]; then
			echo "${candidate}"
			return 0
		fi
	fi

	return 1
}

KERNEL_ROOT="$(find_kernel_root || true)"
if [ -z "${KERNEL_ROOT}" ]; then
	echo "[clutch-signals] FATAL: could not locate the kernel source root" >&2
	echo "[clutch-signals]   cwd was: $(pwd)" >&2
	echo "[clutch-signals]   looked for block/Kconfig.iosched and kernel/sched/Makefile" >&2
	echo "[clutch-signals]   under cwd, its ancestors, and common sibling dirs." >&2
	echo "[clutch-signals]   Set KERNEL_DIR (or KERNEL_SRC_DIR) to the kernel tree" >&2
	echo "[clutch-signals]   before invoking this script if your layout differs." >&2
	exit 1
fi

if [ "${KERNEL_ROOT}" != "$(pwd)" ]; then
	echo "[clutch-signals] cwd was $(pwd), kernel root is ${KERNEL_ROOT} -- cd'ing there"
fi
cd "${KERNEL_ROOT}"

echo "[clutch-signals] applying ${PATCH_FILE} (in $(pwd))"
if ! patch -p1 --fuzz=0 --forward --dry-run < "${PATCH_FILE}" > /dev/null 2>&1; then
	echo "[clutch-signals] dry-run failed, re-running for diagnostics:"
	echo "[clutch-signals]   cwd: $(pwd)"
	ls -la block/Kconfig.iosched kernel/sched/Makefile 2>&1 || true
	patch -p1 --fuzz=0 --forward --dry-run < "${PATCH_FILE}"
	exit 1
fi

patch -p1 --fuzz=0 --forward < "${PATCH_FILE}"
echo "[clutch-signals] applied OK"
