#!/usr/bin/env bash
# ======================================================
# 🔭 Scout pre-check — "is there anything new to test?"
# ======================================================
# Runs BEFORE pin-scout.yml dispatches the (expensive) Warm Run. Compares the
# upstream branch tip of every tracked component with the manifest, using the
# same decision rules as scout.sh/resolve_component, and sets
#   needs_build=true|false   (to $GITHUB_OUTPUT)
# so the 3-variant build is only dispatched when scout.sh would actually pick
# a candidate. Uses `git ls-remote` (no API token, no rate limit).
#
# Fail-open: any error here => needs_build=true (never silently stop scouting).
#
# KEEP IN SYNC with scout.sh: COMPONENTS mirrors the SUSFS-enabled variants
# pin-scout.yml dispatches (resukisu, sukisu, ksunext with susfs=enable).
#
# Env in : KERNEL_VERSION (default 6.1)   SAGA_PATCH_DIR (default repo root)
#          FORCE=true  -> skip the check, always needs_build=true

set -uo pipefail

# key | git url | ref   (ref = branch tip, same sources as scout.sh)
COMPONENTS=(
  "resukisu|https://github.com/ReSukiSU/ReSukiSU.git|refs/heads/main"
  "susfs_resukisu|https://gitlab.com/simonpunk/susfs4ksu.git|refs/heads/gki-android14-6.1"
  "sukisu_builtin|https://github.com/SukiSU-Ultra/SukiSU-Ultra.git|refs/heads/builtin"
  "susfs_sukisu|https://gitlab.com/simonpunk/susfs4ksu.git|refs/heads/gki-android14-6.1"
  "ksunext_susfs_fork|https://github.com/pershoot/KernelSU-Next.git|refs/heads/dev-susfs"
  "susfs_ksunext|https://gitlab.com/pershoot/susfs4ksu.git|refs/heads/gki-android14-6.1-dev"
)

# Overridable in tests. Prints the SHA, or nothing on failure.
remote_sha() {
  timeout 30 git ls-remote "$1" "$2" 2>/dev/null | awk 'NR==1{print $1}'
}

# Same rules as scout.sh resolve_component (candidate needed?)
# Args: good bad_json latest   ->  prints "yes <reason>" / "no <reason>"
decide() {
  local good="$1" bad_json="$2" latest="$3" is_bad good_bad
  if [ -z "$latest" ]; then echo "no lookup failed (pin kept)"; return; fi
  is_bad=$(jq --arg s "$latest" 'any(. == $s)' <<<"$bad_json")
  if [ "$latest" = "$good" ]; then
    good_bad=$(jq --arg s "$good" 'any(. == $s)' <<<"$bad_json")
    if [ "$good_bad" = "true" ]; then echo "yes pin flagged bad (re-verify)"; else echo "no up to date"; fi
  elif [ "$is_bad" = "true" ]; then
    if [ -z "$good" ]; then echo "yes known-bad but no good pin (deadlock retry)"; else echo "no latest is known-bad"; fi
  else
    echo "yes new candidate"
  fi
}

main() {
  local root="${SAGA_PATCH_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  local kv="${KERNEL_VERSION:-6.1}" out="${GITHUB_OUTPUT:-/dev/stdout}"
  local sum="${GITHUB_STEP_SUMMARY:-/dev/null}"

  if [ "${FORCE:-false}" = "true" ]; then
    echo "needs_build=true" >> "$out"; echo "Forced run — skipping pre-check."
    echo "### 🔭 Pin Scout: forced run (pre-check skipped)" >> "$sum"; return 0
  fi

  local manifest; manifest=$(find "$root/kernel" -maxdepth 2 -path "*android*-${kv}-lts/manifest.json" | head -1)
  if [ -z "$manifest" ]; then
    echo "::warning::no manifest for kernel ${kv} — dispatching (fail-open)"
    echo "needs_build=true" >> "$out"; return 0
  fi

  local needs=false row key url ref good bad latest verdict
  {
    echo "### 🔭 Pin Scout pre-check (kernel ${kv})"
    echo "| Component | Pin | Upstream | Verdict |"
    echo "|---|---|---|---|"
  } >> "$sum"
  for row in "${COMPONENTS[@]}"; do
    IFS='|' read -r key url ref <<<"$row"
    good=$(jq -r ".${key}.good // \"\"" "$manifest")
    bad=$(jq -c ".${key}.bad // []" "$manifest")
    latest=$(remote_sha "$url" "$ref")
    [ -n "$latest" ] || echo "::warning::scout-precheck: couldn't read upstream for ${key} (${url} ${ref})"
    verdict=$(decide "$good" "$bad" "$latest")
    case "$verdict" in yes*) needs=true ;; esac
    echo "scout-precheck: ${key}: pin=${good:0:12} upstream=${latest:0:12} -> ${verdict}"
    echo "| ${key} | \`${good:0:12}\` | \`${latest:0:12}\` | ${verdict} |" >> "$sum"
  done

  echo "needs_build=${needs}" >> "$out"
  if [ "$needs" = "true" ]; then echo "➡️ Something new to test — dispatching the Warm Run."
  else echo "💤 Nothing new upstream — skipping the Warm Run (saves ~3 runner jobs)."; fi
  echo "" >> "$sum"; echo "**Result:** needs_build=\`${needs}\`" >> "$sum"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main || { echo "::warning::pre-check crashed — dispatching anyway (fail-open)"; echo "needs_build=true" >> "${GITHUB_OUTPUT:-/dev/stdout}"; }
fi
