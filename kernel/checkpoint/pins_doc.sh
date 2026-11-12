#!/usr/bin/env bash
# ======================================================
# 📌 PINS.md generator (T19)
# ======================================================
# Prints docs/PINS.md (Markdown) from every kernel/android*-*-lts/manifest.json.
# engine.sh regenerates it inside each pin commit; run it by hand with:
#   bash kernel/checkpoint/pins_doc.sh > docs/PINS.md
#
# The "Verified" column comes from manifest `.<component>.verified` ({run, at}),
# which engine.sh writes when it promotes a pin. Pins promoted before that
# field existed show "—".

set -uo pipefail
ROOT="${SAGA_PATCH_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Component -> upstream (key|git url|ref). Reuses scout_precheck.sh's table so
# there is a single list; "sukisu" (stable release tag) is not in it.
# shellcheck source=/dev/null
source "${ROOT}/kernel/checkpoint/scout_precheck.sh"
declare -A WEB
for row in "${COMPONENTS[@]}"; do
  IFS='|' read -r k url _ <<<"$row"; WEB[$k]="${url%.git}"
done
WEB[sukisu]="https://github.com/SukiSU-Ultra/SukiSU-Ultra"

commit_link() {  # key sha
  local web="${WEB[$1]:-}" short="${2:0:10}"
  [ -n "$2" ] || { printf -- '—'; return; }
  case "$web" in
    '')                printf '`%s`' "$short" ;;
    *gitlab.com*)      printf '[`%s`](%s/-/commit/%s)' "$short" "$web" "$2" ;;
    *)                 printf '[`%s`](%s/commit/%s)' "$short" "$web" "$2" ;;
  esac
}

echo "# Pins verificados"
echo
echo "> Gerado automaticamente por \`kernel/checkpoint/engine.sh\` a cada promoção ou bloqueio de pin. **Não edite à mão.**"
echo "> Para regenerar: \`bash kernel/checkpoint/pins_doc.sh > docs/PINS.md\`."
echo
echo "- **Pin (good):** último commit que compilou e é usado nas builds normais."
echo "- **Ruins:** quantos commits do upstream já falharam e são ignorados."
echo "- **Verificado:** data (UTC) e run da build que promoveu o pin."

for manifest in "${ROOT}"/kernel/android*-*-lts/manifest.json; do
  [ -f "$manifest" ] || continue
  dir=$(basename "$(dirname "$manifest")")
  echo; echo "## ${dir}"; echo
  echo "| Componente | Pin (good) | Ruins | Verificado | Run |"
  echo "|---|---|---|---|---|"
  while IFS=$'\t' read -r key good nbad at run; do
    link=$(commit_link "$key" "$good")
    runcell="—"
    if [ -n "$run" ] && [ "$run" != "null" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
      runcell="[${run}](${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${run})"
    elif [ -n "$run" ] && [ "$run" != "null" ]; then runcell="$run"; fi
    [ "$at" = "null" ] && at="—"
    echo "| \`${key}\` | ${link} | ${nbad} | ${at} | ${runcell} |"
  done < <(jq -r 'to_entries[] | [.key, (.value.good // ""), ((.value.bad // []) | length), (.value.verified.at // "null"), (.value.verified.run // "null")] | @tsv' "$manifest")
done
