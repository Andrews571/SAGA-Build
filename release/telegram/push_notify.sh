#!/usr/bin/env bash
# Push notification for notify.yml.
# Env in : TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID TELEGRAM_THREAD_ID_EVENT
#          COMMIT BEFORE BRANCH MESSAGE AUTHOR URL
# TG_DRY_RUN=1 prints the message instead of sending it (local tests).
export LC_ALL=C.UTF-8
set -u

TG_LIMIT=4096       # Telegram hard limit per message
BODY_MAX=2500       # raw chars kept from the commit body before escaping

html_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# T15: icon by Conventional Commit prefix (feat, fix(scope), chore!, ...)
icon_for() {
  local t="$1" type=""
  if [[ "$t" =~ ^([a-zA-Z]+)(\([^\)]*\))?\!?: ]]; then type="${BASH_REMATCH[1],,}"; fi
  case "$type" in
    feat)            echo "✨" ;;
    fix)             echo "🐛" ;;
    chore)           echo "🧹" ;;
    perf)            echo "⚡" ;;
    docs)            echo "📝" ;;
    refactor)        echo "♻️" ;;
    ci|build)        echo "⚙️" ;;
    test)            echo "🧪" ;;
    revert)          echo "⏪" ;;
    *)               echo "📌" ;;
  esac
}

# T3: automatic pin maintenance commits arrive silently
is_silent() { [[ "$1" =~ ^[Cc]hore(\([^\)]*\))?:[[:space:]]+(bump|mark)[[:space:]] ]]; }

# T14: "3 files +45/−12" for the whole push (falls back to the head commit)
diff_stats() {
  local out=""
  if [ -n "${BEFORE:-}" ] && [[ ! "$BEFORE" =~ ^0+$ ]] && git cat-file -e "${BEFORE}^{commit}" 2>/dev/null; then
    out=$(git diff --shortstat "$BEFORE" "$COMMIT" 2>/dev/null)
  else
    out=$(git show --shortstat --format= "$COMMIT" 2>/dev/null)
  fi
  [ -z "$out" ] && return 0
  local f a d
  f=$(sed -n 's/^ *\([0-9]\+\) file.*/\1/p' <<<"$out")
  a=$(sed -n 's/.* \([0-9]\+\) insertion.*/\1/p' <<<"$out")
  d=$(sed -n 's/.* \([0-9]\+\) deletion.*/\1/p' <<<"$out")
  printf '%s file%s +%s/−%s' "${f:-0}" "$([ "${f:-0}" = 1 ] || echo s)" "${a:-0}" "${d:-0}"
}

# T14: number of commits in the push (1 when BEFORE is unknown, e.g. new branch)
count_commits() {
  if [ -n "${BEFORE:-}" ] && [[ ! "$BEFORE" =~ ^0+$ ]] && git cat-file -e "${BEFORE}^{commit}" 2>/dev/null; then
    git rev-list --count "${BEFORE}..${COMMIT}" 2>/dev/null || echo 1
  else
    echo 1
  fi
}

build_text() {  # $1 = body (raw, already truncated)
  local text
  text=$(printf '%s New Commit : <a href="%s">%s</a>\nBranch : <code>%s</code>\nAuthor : %s' \
    "$ICON" "$URL" "$SHORT_COMMIT" "$BRANCH" "$AUTHOR_ESC")
  [ "${COMMIT_COUNT:-1}" -gt 1 ] 2>/dev/null && text=$(printf '%s\nCommits : %s' "$text" "$COMMIT_COUNT")
  [ -n "$STATS" ] && text=$(printf '%s\nChanges : %s' "$text" "$STATS")
  text=$(printf '%s\n\nTitle:\n<i>%s</i>' "$text" "$TITLE_ESC")
  if [ -n "$1" ]; then
    text=$(printf '%s\n\nMessage:\n<pre>%s</pre>' "$text" "$(html_escape "$1")")
  fi
  printf '%s' "$text"
}

SHORT_COMMIT="${COMMIT:0:7}"
TITLE=$(printf '%s' "$MESSAGE" | head -1)
BODY=$(printf '%s' "$MESSAGE" | tail -n +3)
TITLE_ESC=$(html_escape "$TITLE")
AUTHOR_ESC=$(html_escape "$AUTHOR")
ICON=$(icon_for "$TITLE")
STATS=$(diff_stats)
COMMIT_COUNT=$(count_commits)

# T13: truncate the body, then shrink until the whole message fits
if [ "${#BODY}" -gt "$BODY_MAX" ]; then BODY="${BODY:0:$BODY_MAX}"$'\n'"… (truncated, see commit)"; fi
TEXT=$(build_text "$BODY")
while [ "${#TEXT}" -gt "$TG_LIMIT" ] && [ -n "$BODY" ]; do
  BODY="${BODY:0:$(( ${#BODY} / 2 ))}"$'\n'"… (truncated, see commit)"
  [ "${#BODY}" -lt 40 ] && BODY=""
  TEXT=$(build_text "$BODY")
done

SILENT=false; is_silent "$TITLE" && SILENT=true

if [ "${TG_DRY_RUN:-0}" = 1 ]; then
  printf 'silent=%s len=%s\n%s\n' "$SILENT" "${#TEXT}" "$TEXT"; exit 0
fi

source "$GITHUB_WORKSPACE/functions.sh"
source "$GITHUB_WORKSPACE/release/telegram/config.sh"
source "$GITHUB_WORKSPACE/release/telegram/common.sh"

if telegram_api_call "sendMessage" /tmp/tg_push_response.json "Push notify" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "message_thread_id=${TELEGRAM_THREAD_ID_EVENT}" \
      -d "parse_mode=HTML" \
      -d "disable_web_page_preview=true" \
      -d "disable_notification=${SILENT}" \
      --data-urlencode "text=${TEXT}"; then
  log "Notify sent ✅ (silent=${SILENT})"
fi
rm -f /tmp/tg_push_response.json
