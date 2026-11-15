#!/usr/bin/env bash
# ======================================================
# 🧪 ZIP sanity check (T16) — runs right after the zip is created
# ======================================================
# Usage: zip_check.sh <zip> [expected_linux_version]   (e.g. 6.1.190)
#
# Fails (exit 1) when the zip would be a broken release:
#   - the archive is corrupt (unzip -t)
#   - anykernel.sh is missing
#   - no kernel image (Image, Image.gz, Image.gz-dtb, Image-dtb)
#   - the image is implausibly small (ZIP_MIN_IMAGE_MB, default 5)
#   - the "Linux version X.Y.Z" banner inside the image differs from the expected one
# If the banner can't be read it only WARNS (never fails on "unknown").
# Takes a few seconds: it reads the image once.

set -uo pipefail

ZIP_MIN_IMAGE_MB="${ZIP_MIN_IMAGE_MB:-5}"

zc_fail() { echo "::error title=ZIP check::$*"; return 1; }

check_zip() {
  local zip="$1" expect="${2:-}" listing img="" name size_b banner got

  [ -f "$zip" ] || { zc_fail "zip not found: $zip"; return 1; }
  unzip -tq "$zip" > /dev/null 2>&1 || { zc_fail "zip is corrupt (unzip -t failed): $(basename "$zip")"; return 1; }

  listing=$(unzip -Z -l "$zip" 2>/dev/null) || { zc_fail "can't list zip contents"; return 1; }
  grep -qE ' (\./)?anykernel\.sh$' <<<"$listing" || { zc_fail "anykernel.sh missing from the zip"; return 1; }

  for name in Image Image.gz Image.gz-dtb Image-dtb; do
    if grep -qE " (\./)?${name}\$" <<<"$listing"; then img="$name"; break; fi
  done
  [ -n "$img" ] || { zc_fail "no kernel image in the zip (Image, Image.gz, Image.gz-dtb, Image-dtb)"; return 1; }

  # uncompressed size of the image entry (field 4 of 'unzip -Z -l' = size in bytes)
  size_b=$(awk -v n="$img" '$NF==n || $NF=="./"n {print $4; exit}' <<<"$listing")
  if [ -n "$size_b" ] && [ "$size_b" -lt $(( ZIP_MIN_IMAGE_MB * 1024 * 1024 )) ]; then
    zc_fail "${img} is only $(( size_b / 1024 )) KiB (min ${ZIP_MIN_IMAGE_MB} MiB) — the build output looks truncated"; return 1
  fi

  if [ -n "$expect" ]; then
    case "$img" in
      Image|Image-dtb)     banner=$(unzip -p "$zip" "$img" 2>/dev/null | grep -a -o -m1 'Linux version [0-9][0-9.]*') ;;
      Image.gz|Image.gz-dtb) banner=$(unzip -p "$zip" "$img" 2>/dev/null | gzip -dc 2>/dev/null | grep -a -o -m1 'Linux version [0-9][0-9.]*') ;;
    esac
    got="${banner#Linux version }"
    if [ -z "$got" ]; then
      echo "::warning title=ZIP check::couldn't read the 'Linux version' banner from ${img}; version check skipped"
    elif [ "$got" != "$expect" ]; then
      zc_fail "kernel banner says Linux ${got} but this build is ${expect}"; return 1
    fi
  fi

  echo "🧪 ZIP check OK: $(basename "$zip") — ${img} $(( ${size_b:-0} / 1048576 )) MiB, banner ${got:-unknown}"
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "- 🧪 ZIP check OK: \`$(basename "$zip")\` (${img}, ${got:-banner n/a})" >> "$GITHUB_STEP_SUMMARY"
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then check_zip "$@"; fi
