#!/usr/bin/env bash
# SAGA-Build addon: clutch-signals
# Shared, neutral bridge storage between ADIOS (I/O) and CC governor
# (CPU), plus the memory-pressure signal written by the memory
# subsystem. Must be applied BEFORE adios-clutch and cc-governor.
set -euo pipefail

PATCH_FILE="$(dirname "${BASH_SOURCE[0]}")/clutch-signals-android14-6.1.patch"

echo "[clutch-signals] applying ${PATCH_FILE}"
if ! patch -p1 --fuzz=0 --forward --dry-run < "${PATCH_FILE}" > /dev/null 2>&1; then
	echo "[clutch-signals] dry-run failed, re-running for diagnostics:"
	patch -p1 --fuzz=0 --forward --dry-run < "${PATCH_FILE}"
	exit 1
fi

patch -p1 --fuzz=0 --forward < "${PATCH_FILE}"
echo "[clutch-signals] applied OK"
