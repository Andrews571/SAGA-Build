#!/usr/bin/env bash
# ======================================================
# 📊 ccache report — hit rate of THIS build + size verdict
# ======================================================
# build/make.sh zeroes the stats right before compiling, so the numbers here
# cover only this build (not the whole history stored inside the cache).
# Prints the classic --show-stats, then a one-line verdict and a job-summary
# table. Never fails the job.
#
# Env in : MX_LABEL (e.g. "RESUKISU+SUSFS"), CCACHE_MAXSIZE (e.g. 900M),
#          CCACHE_BIN (default ~/ccache-bin/ccache), CCACHE_MIN_HIT_RATE (default 90)

set -uo pipefail

# "900M" / "2G" / "512K" / "1024" -> KiB
size_to_kib() {
  case "${1:-}" in
    *[Gg]) echo $(( ${1%[Gg]} * 1024 * 1024 )) ;;
    *[Mm]) echo $(( ${1%[Mm]} * 1024 )) ;;
    *[Kk]) echo "${1%[Kk]}" ;;
    ''|*[!0-9]*) echo 0 ;;
    *) echo $(( $1 / 1024 )) ;;
  esac
}

# Reads the stats of the cache. Prints: "<hits> <misses> <cleanups> <size_kib>"
# 1) machine-readable --print-stats (ccache >= 4.0); 2) parse --show-stats text.
collect() {
  local bin="$1" ps text h m c s dh ph
  ps=$("$bin" --print-stats 2>/dev/null || true)
  get() { awk -F'\t' -v k="$1" '$1==k{print $2; exit}' <<<"$ps"; }
  dh=$(get direct_cache_hit); ph=$(get preprocessed_cache_hit); m=$(get cache_miss)
  if [ -n "$dh" ] && [ -n "$m" ]; then
    c=$(get cleanups_performed); s=$(get cache_size_kibibyte)
    echo "$(( dh + ${ph:-0} )) ${m} ${c:-0} ${s:-0}"; return 0
  fi
  text=$("$bin" --show-stats 2>/dev/null || true)
  h=$(sed -n 's/^ *Hits: *\([0-9]\+\) .*/\1/p' <<<"$text" | head -1)
  m=$(sed -n 's/^ *Misses: *\([0-9]\+\) .*/\1/p' <<<"$text" | head -1)
  if [ -z "$h" ]; then   # ccache 3.x / early 4.x wording
    dh=$(sed -n 's/^ *cache hit (direct) *\([0-9]\+\).*/\1/p' <<<"$text" | head -1)
    ph=$(sed -n 's/^ *cache hit (preprocessed) *\([0-9]\+\).*/\1/p' <<<"$text" | head -1)
    m=$(sed -n 's/^ *cache miss *\([0-9]\+\).*/\1/p' <<<"$text" | head -1)
    [ -n "$dh$ph" ] && h=$(( ${dh:-0} + ${ph:-0} ))
  fi
  [ -n "${h:-}" ] && [ -n "${m:-}" ] || return 1
  c=$(sed -n 's/^ *Cleanups: *\([0-9]\+\).*/\1/p' <<<"$text" | head -1)
  echo "${h} ${m} ${c:-0} 0"
}

# Args: hits misses cleanups size_kib max_kib min_rate -> prints "<rate>|<icon>|<message>"
verdict() {
  local hits="$1" miss="$2" clean="$3" size="$4" max="$5" min="$6" total rate full=false
  total=$(( hits + miss ))
  if [ "$total" -eq 0 ]; then echo "n/a|ℹ️|no compiler calls were recorded"; return; fi
  rate=$(awk -v h="$hits" -v t="$total" 'BEGIN{printf "%.1f", h*100/t}')
  if [ "$clean" -gt 0 ] || { [ "$max" -gt 0 ] && [ "$size" -ge $(( max * 9 / 10 )) ]; }; then full=true; fi
  if awk -v r="$rate" -v m="$min" 'BEGIN{exit !(r>=m)}'; then
    echo "${rate}|✅|hit rate on target — the cache limit is enough"
  elif [ "$full" = true ]; then
    echo "${rate}|⚠️|below ${min}% and the cache is full/evicting — raise CCACHE_MAXSIZE"
  else
    echo "${rate}|ℹ️|below ${min}% but the cache is not full — likely a cold cache or lots of changed code, not a size problem"
  fi
}

main() {
  local bin="${CCACHE_BIN:-$HOME/ccache-bin/ccache}" min="${CCACHE_MIN_HIT_RATE:-90}"
  local label="${MX_LABEL:-build}" sum="${GITHUB_STEP_SUMMARY:-/dev/null}"
  [ -x "$bin" ] || { echo "ccache binary not found at $bin — skipping report"; return 0; }

  "$bin" --show-stats || true
  local data hits miss clean size max v rate icon msg rate_txt
  data=$(collect "$bin") || { echo "::notice::ccache report: couldn't parse stats"; return 0; }
  read -r hits miss clean size <<<"$data"
  max=$(size_to_kib "${CCACHE_MAXSIZE:-}")
  v=$(verdict "$hits" "$miss" "$clean" "$size" "$max" "$min")
  IFS='|' read -r rate icon msg <<<"$v"

  [ "$rate" = "n/a" ] && rate_txt="n/a" || rate_txt="${rate}%"
  echo "${icon} ccache hit rate (${label}): ${rate_txt} — ${hits} hits / ${miss} misses; cleanups=${clean}; ${msg}"
  [ "$icon" = "⚠️" ] && echo "::warning title=ccache (${label})::hit rate ${rate_txt} — ${msg}"
  {
    echo "### 📊 ccache — ${label}"
    echo "| Hit rate | Hits | Misses | Cleanups | Cache size | Limit |"
    echo "|---|---|---|---|---|---|"
    echo "| ${icon} **${rate_txt}** | ${hits} | ${miss} | ${clean} | $(( size / 1024 )) MiB | ${CCACHE_MAXSIZE:-?} |"
    echo ""; echo "${msg}"; echo ""
  } >> "$sum"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main || true; fi
