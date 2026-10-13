#!/usr/bin/env bash
# SAGA-Build addon: clutch-signals
# Shared, neutral bridge storage between ADIOS (I/O) and CC governor
# (CPU), plus the memory-pressure signal written by the memory
# subsystem. Must be applied BEFORE adios-clutch and cc-governor.
set -euo pipefail

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/clutch-signals-android14-6.1.patch"

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

	# Common sibling layouts: kernel source checked out next to the
	# SAGA-Build workspace root rather than inside it.
	for candidate in "$(pwd)"/kernel_source "$(pwd)"/../kernel_source "$(pwd)"/common "$(pwd)"/../common; do
		if [ -f "${candidate}/block/Kconfig.iosched" ] && [ -f "${candidate}/kernel/sched/Makefile" ]; then
			(cd "${candidate}" && pwd)
			return 0
		fi
	done

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
