#!/usr/bin/env bash
# ======================================================
# 🧩 Patch-failure issue (T22)
# ======================================================
# Sourced by engine.sh after a FAILED build. If the failure looks like a patch
# that no longer applies (error() message says so, or `patch` left *.rej files
# in the kernel tree), opens — or comments on — a GitHub Issue that contains
# the failing step, the run link and the rejected hunks, so nobody has to dig
# through the log.
#
# Env in : KERNEL_VERSION, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_SERVER_URL,
#          MX_KERNEL_VARIANT (optional), SAGA_PATCH_DIR, KERNEL_SRC (optional),
#          SAGA_LAST_ERROR_FILE (optional), GH_TOKEN
# Dedup  : by title ("🧩 Patch failed to apply: <step> (<kernel>)").
# Not auto-closed: the same patch can pass in one variant/profile and still be
# broken in another, so close it by hand once the patch is fixed.

PATCH_ISSUE_MAX_CHARS="${PATCH_ISSUE_MAX_CHARS:-3500}"

# Last error message without ANSI colors; empty if none.
patch_last_error() {
  local f="${SAGA_LAST_ERROR_FILE:-${RUNNER_TEMP:-/tmp}/saga-last-error.txt}"
  [ -s "$f" ] && sed 's/\x1b\[[0-9;]*m//g' "$f" | head -3
}

# Rejected hunks from patch(1): "### path" + first lines of each .rej, truncated.
patch_rej_excerpt() {
  local root="${KERNEL_SRC:-${SAGA_PATCH_DIR:-.}/workspace/kernel/common}" out="" f n=0
  [ -d "$root" ] || return 0
  while IFS= read -r f; do
    n=$(( n + 1 )); [ "$n" -gt 12 ] && break
    out+=$'\n'"### ${f#"$root"/}"$'\n'"$(head -n 40 "$f")"$'\n'
  done < <(find "$root" -name '*.rej' 2>/dev/null | sort)
  [ -n "$out" ] || return 0
  if [ "${#out}" -gt "$PATCH_ISSUE_MAX_CHARS" ]; then out="${out:0:$PATCH_ISSUE_MAX_CHARS}"$'\n'"... (truncated — see the run log)"; fi
  printf '%s' "$out"
}

# Prints "<step label>" when the failure is a patch failure, nothing otherwise.
patch_failure_label() {
  local msg rej
  msg=$(patch_last_error | head -1)
  rej=$(patch_rej_excerpt)
  if [[ "$msg" =~ ([Aa]pply\ failed|[Pp]atch\ file\ not\ found|[Pp]atch.*failed|hunk) ]]; then
    # "mm stable catch-up: apply failed!" -> "mm stable catch-up"
    local label="${msg%%:*}"; [ "$label" = "$msg" ] && label="${msg:0:60}"
    printf '%s' "$label"
  elif [ -n "$rej" ]; then
    printf 'patch (rejected hunks)'
  fi
}

report_patch_failure() {
  command -v gh > /dev/null 2>&1 || return 0
  [ -n "${GH_TOKEN:-}" ] || return 0
  local label; label=$(patch_failure_label)
  [ -n "$label" ] || return 0

  local title="🧩 Patch failed to apply: ${label} (${KERNEL_VERSION:-?})"
  local run_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-0}"
  local msg rej body
  msg=$(patch_last_error); rej=$(patch_rej_excerpt)
  body="A patch stopped applying — usually because the kernel source or an upstream component changed.

- **Step:** ${label}
- **Kernel:** ${KERNEL_VERSION:-?}   **Variant:** ${MX_KERNEL_VARIANT:-?}
- **Run:** ${run_url}
- **Error:** \`${msg:-n/a}\`
"
  if [ -n "$rej" ]; then
    body+="
<details><summary>Rejected hunks</summary>

\`\`\`
${rej}
\`\`\`
</details>
"
  fi
  body+="
Regenerate/rebase the patch against the current source. This issue is **not** auto-closed: close it when the fix is merged."

  local existing
  existing=$(gh issue list --repo "$GITHUB_REPOSITORY" --state open --search "in:title \"${title}\"" --json number --jq '.[0].number' 2> /dev/null || true)
  if [ -n "$existing" ] && [ "$existing" != "null" ]; then
    gh issue comment "$existing" --repo "$GITHUB_REPOSITORY" --body "$body" || echo "report_patch_failure: couldn't comment on #${existing}" >&2
  else
    gh label create "patch-broken" --repo "$GITHUB_REPOSITORY" --color "e99695" \
      --description "Auto-filed: a patch no longer applies" 2> /dev/null || true
    gh issue create --repo "$GITHUB_REPOSITORY" --title "$title" --body "$body" --label "patch-broken" \
      || echo "report_patch_failure: couldn't create the issue" >&2
  fi
}
