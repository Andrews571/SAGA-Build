#!/usr/bin/env bash
# ======================================================
# ❌ Failure alert (T12) — Telegram message when a Build/Release run fails
# ======================================================
# Lists the jobs that failed (with the failing step and a direct link to each log)
# and posts to the matching topic: Release -> release thread, Build -> test thread.
# Best effort: never fails the workflow.
#
# Env in : TELEGRAM_BOT_TOKEN, GH_TOKEN (github.token, actions: read), GITHUB_REPOSITORY,
#          GITHUB_RUN_ID, GITHUB_SERVER_URL, GITHUB_ACTOR, RUN_MODE, KERNEL_VERSION, ADDON_PROFILE
#          TG_DRY_RUN=1 prints the message instead of sending it (tests).

set -uo pipefail
html() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

failed_jobs() {  # TSV: job name <TAB> job url <TAB> failing step
  gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs?per_page=100" \
    --jq '.jobs[] | select(.conclusion=="failure") | [.name, .html_url, (([.steps[] | select(.conclusion=="failure" or .conclusion=="timed_out" or .conclusion=="cancelled")][0].name) // "")] | @tsv' 2>/dev/null
}

build_text() {
  local name="SAGA" run_url jobs n u s
  [ "${ADDON_PROFILE:-}" = "CC_Addons" ] && name="SAGA_CC"
  [ "${ADDON_PROFILE:-}" = "Test_Addons" ] && name="SAGA_TEST"
  run_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
  printf '❌ <b>%s build failed</b>\n' "$name"
  printf 'Mode: %s · Kernel %s · by %s\n' "$(html "${RUN_MODE:-?}")" "$(html "${KERNEL_VERSION:-?}")" "$(html "${GITHUB_ACTOR:-?}")"
  jobs=$(failed_jobs || true)
  if [ -n "$jobs" ]; then
    printf '\n<b>Failed</b>\n'
    while IFS=$'\t' read -r n u s; do
      [ -n "$n" ] || continue
      if [ -n "$s" ]; then printf '• <a href="%s">%s</a> — step “%s”\n' "$u" "$(html "$n")" "$(html "$s")"
      else printf '• <a href="%s">%s</a> — no failed step recorded (cancelled, timed out or runner problem)\n' "$u" "$(html "$n")"; fi
    done <<<"$jobs"
  fi
  printf '\n🔗 <a href="%s">Open the run</a>' "$run_url"
}

main() {
  local text; text=$(build_text)
  if [ "${TG_DRY_RUN:-0}" = 1 ]; then printf '%s\n' "$text"; return 0; fi

  : "${SAGA_PATCH_DIR:=$PWD}"
  # shellcheck source=/dev/null
  source "${SAGA_PATCH_DIR}/functions.sh"
  # shellcheck source=/dev/null
  source "${SAGA_PATCH_DIR}/release/telegram/config.sh"
  # shellcheck source=/dev/null
  source "${SAGA_PATCH_DIR}/release/telegram/common.sh"
  TELEGRAM_API_TIMEOUT="${TELEGRAM_API_TIMEOUT:-60}"; TELEGRAM_MAX_RETRIES="${TELEGRAM_MAX_RETRIES:-3}"
  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] || { warn "failure alert skipped: TELEGRAM_BOT_TOKEN not set"; return 0; }

  local thread
  case "${RUN_MODE:-}" in
    Release) thread="${TELEGRAM_THREAD_ID_RELEASE:-}" ;;
    Build)   thread="${TELEGRAM_THREAD_ID_TEST:-}" ;;
    *)       thread="${TELEGRAM_THREAD_ID_EVENT:-}" ;;
  esac
  telegram_api_call "sendMessage" /tmp/tg_failure_alert.json "Failure alert" \
      -F "chat_id=${TELEGRAM_CHAT_ID}" \
      ${thread:+-F "message_thread_id=${thread}"} \
      -F "parse_mode=HTML" \
      -F "disable_web_page_preview=true" \
      --form-string "text=${text}" \
    && log "❌ failure alert sent" || warn "failure alert could not be sent"
  rm -f /tmp/tg_failure_alert.json
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main || true; fi
