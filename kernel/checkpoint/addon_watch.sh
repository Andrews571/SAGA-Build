#!/usr/bin/env bash
# ======================================================
# 📦 Addon watch — upstream das addons (T20)
# ======================================================
# Cada kernel/addons/<nome>/addon.meta descreve a origem do addon. Este script:
#   check [--report]  compara o upstream com o último estado revisado (`seen`).
#                     --report abre/atualiza/fecha a issue "📦 Addon upstream updates".
#   accept <nome|all> marca o upstream atual como revisado (reescreve seen/seen_at).
#   validate          confere os addon.meta (usado pelo Lint; falha em erro).
#   doc               imprime a tabela Markdown dos addons (docs/ADDONS-LISTA.md).
#
# Só INFORMA: não altera build nem pins. Addons `fetch-latest`/`git-clone` já usam
# o upstream mais novo a cada build, então a issue avisa que algo pode ter mudado
# antes de quebrar; `vendored-patch` avisa que existe versão nova para revisar.
#
# track: none | branch (topo da branch) | path (último commit que toca track_path)
# Env: GH_TOKEN (opcional; sem ele o `path` usa clone parcial como fallback)

set -uo pipefail
ROOT="${SAGA_PATCH_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ADDONS_DIR="${ADDONS_DIR:-${ROOT}/kernel/addons}"
ISSUE_TITLE="📦 Addon upstream updates"

meta_get() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-; }
slug_of()  { local u="${1%.git}"; echo "${u#https://github.com/}"; }
short()    { printf '%s' "${1:0:10}"; }

# ---- lookups (printing the sha, or nothing on failure) ----
latest_branch() {  # url ref
  local ref="${2:-HEAD}"; [ "$ref" = HEAD ] || ref="refs/heads/${ref}"
  timeout 30 git ls-remote "${1%.git}.git" "$ref" 2>/dev/null | awk 'NR==1{print $1}'
}
latest_path() {  # url ref path
  local url="${1%.git}" ref="$2" path="$3" slug enc
  slug=$(slug_of "$url")
  if command -v gh > /dev/null 2>&1 && [ -n "${GH_TOKEN:-}" ] && command -v jq > /dev/null 2>&1; then
    enc=$(jq -rn --arg p "$path" '$p|@uri')
    gh api "repos/${slug}/commits?sha=${ref}&path=${enc}&per_page=1" --jq '.[0].sha // empty' 2>/dev/null && return 0
  fi
  # fallback without token: partial clone + git log on the path
  local tmp; tmp=$(mktemp -d)
  if timeout 120 git clone -q --filter=blob:none --no-checkout --single-branch --branch "$ref" "${url}.git" "$tmp" 2>/dev/null; then
    git -C "$tmp" log -1 --format=%H -- "$path" 2>/dev/null
  fi
  rm -rf "$tmp"
}
latest_of() {  # meta file -> sha
  local f="$1" track up ref path
  track=$(meta_get "$f" track); up=$(meta_get "$f" upstream)
  ref=$(meta_get "$f" track_ref); path=$(meta_get "$f" track_path)
  case "$track" in
    branch) latest_branch "$up" "$ref" ;;
    path)   latest_path "$up" "$ref" "$path" ;;
  esac
}

metas() { find "$ADDONS_DIR" -mindepth 2 -maxdepth 2 -name addon.meta | sort; }

# ---- check ----
cmd_check() {
  local report=false; [ "${1:-}" = "--report" ] && report=true
  local f name track seen latest changed=0 failed=0 rows="" summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
  {
    echo "### 📦 Addon watch"
    echo "| Addon | Modo | Rastreia | Revisado | Upstream agora | Estado |"
    echo "|---|---|---|---|---|---|"
  } >> "$summary"
  while IFS= read -r f; do
    name=$(meta_get "$f" name); track=$(meta_get "$f" track)
    [ "$track" = none ] && continue
    seen=$(meta_get "$f" seen); latest=$(latest_of "$f")
    local mode up ref path state tgt
    mode=$(meta_get "$f" mode); up=$(meta_get "$f" upstream); ref=$(meta_get "$f" track_ref); path=$(meta_get "$f" track_path)
    tgt="${track}:${ref}${path:+/$path}"
    if [ -z "$latest" ]; then
      state="⚠️ consulta falhou"; failed=$(( failed + 1 ))
      echo "::warning::addon-watch: não consegui consultar o upstream de ${name}"
    elif [ "$latest" = "$seen" ]; then
      state="✅ em dia"
    else
      state="🔔 mudou"; changed=$(( changed + 1 ))
      local link
      if [ "$track" = path ]; then link="${up}/commits/${ref}/${path}"; else link="${up}/compare/$(short "$seen")...$(short "$latest")"; fi
      rows+="| \`${name}\` | ${mode} | [upstream](${up}) | \`$(short "$seen")\` | [\`$(short "$latest")\`](${link}) |"$'\n'
    fi
    echo "| ${name} | ${mode} | ${tgt} | \`$(short "$seen")\` | \`$(short "$latest")\` | ${state} |" >> "$summary"
    echo "addon-watch: ${name}: ${state}"
  done < <(metas)
  echo "addon-watch: changed=${changed} lookup_failed=${failed}"
  [ -n "${GITHUB_OUTPUT:-}" ] && echo "changed=$(( changed > 0 ))" >> "$GITHUB_OUTPUT"
  $report && report_issue "$changed" "$rows"
  return 0
}

report_issue() {  # changed rows
  command -v gh > /dev/null 2>&1 && [ -n "${GH_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ] || { echo "addon-watch: sem gh/token — issue não atualizada"; return 0; }
  local changed="$1" rows="$2" n body
  n=$(gh issue list --repo "$GITHUB_REPOSITORY" --state open --search "in:title \"${ISSUE_TITLE}\"" --json number --jq '.[0].number' 2>/dev/null || true)
  [ "$n" = null ] && n=""
  if [ "$changed" -gt 0 ]; then
    body="O upstream mudou em ${changed} addon(s) desde a última revisão.

| Addon | Modo | Origem | Revisado | Agora |
|---|---|---|---|---|
${rows}
**O que fazer:** olhe a mudança. Addons \`fetch-latest\` e \`git-clone\` já usam o conteúdo novo nas próximas builds (não são fixados); \`vendored-patch\` só tem versão nova para revisar. Se estiver tudo bem, marque como revisado e comite o \`addon.meta\`:

\`\`\`
bash kernel/checkpoint/addon_watch.sh accept <addon>   # ou: accept all
\`\`\`

_Atualizada automaticamente pelo Pin Scout; fecha sozinha quando tudo estiver em dia._"
    if [ -n "$n" ]; then
      gh issue edit "$n" --repo "$GITHUB_REPOSITORY" --body "$body" > /dev/null || echo "addon-watch: não consegui editar #${n}" >&2
    else
      gh label create "addon-upstream" --repo "$GITHUB_REPOSITORY" --color "0e8a16" --description "Auto: upstream de addon mudou" 2> /dev/null || true
      gh issue create --repo "$GITHUB_REPOSITORY" --title "$ISSUE_TITLE" --body "$body" --label "addon-upstream" > /dev/null || echo "addon-watch: não consegui criar a issue" >&2
    fi
  elif [ -n "$n" ]; then
    gh issue close "$n" --repo "$GITHUB_REPOSITORY" --comment "✅ Todos os addons rastreados estão em dia com o upstream." > /dev/null || true
  fi
}

# ---- accept ----
cmd_accept() {
  [ -n "${1:-}" ] || { echo "uso: addon_watch.sh accept <addon|all>" >&2; return 2; }
  local f name latest today; today=$(date -u +%Y-%m-%d); local hit=0
  while IFS= read -r f; do
    name=$(meta_get "$f" name)
    [ "$1" = all ] || [ "$1" = "$name" ] || continue
    [ "$(meta_get "$f" track)" = none ] && { [ "$1" = all ] || echo "$name: track=none, nada a aceitar"; continue; }
    latest=$(latest_of "$f")
    [ -n "$latest" ] || { echo "$name: consulta falhou, nada alterado" >&2; continue; }
    sed -i "s|^seen=.*|seen=${latest}|; s|^seen_at=.*|seen_at=${today}|" "$f"
    echo "$name: seen=$(short "$latest") (${today})"; hit=1
  done < <(metas)
  [ "$hit" = 1 ] || echo "nenhum addon atualizado"
}

# ---- validate ----
cmd_validate() {
  local rc=0 d name f v
  for d in "$ADDONS_DIR"/*/; do
    name=$(basename "$d"); f="${d}addon.meta"
    err() { echo "::error file=${f#"$ROOT"/}::${name}: $*"; rc=1; }
    [ -f "$f" ] || { echo "::error::kernel/addons/${name}: falta addon.meta (ver docs/ADDONS.md)"; rc=1; continue; }
    [ "$(meta_get "$f" name)" = "$name" ] || err "name deve ser '${name}'"
    for k in desc license; do [ -n "$(meta_get "$f" "$k")" ] || err "chave '${k}' vazia"; done
    v=$(meta_get "$f" mode);  case "$v" in local|vendored-patch|fetch-latest|git-clone) ;; *) err "mode inválido '${v}'";; esac
    v=$(meta_get "$f" track); case "$v" in
      none) ;;
      branch|path)
        [ -n "$(meta_get "$f" upstream)" ] || err "track=${v} exige upstream"
        [ -n "$(meta_get "$f" track_ref)" ] || err "track=${v} exige track_ref"
        [ -n "$(meta_get "$f" seen)" ] || err "track=${v} exige seen (rode: addon_watch.sh accept ${name})"
        [ "$v" = path ] && { [ -n "$(meta_get "$f" track_path)" ] || err "track=path exige track_path"; } ;;
      *) err "track inválido '${v}'" ;;
    esac
  done
  [ "$rc" = 0 ] && echo "addon.meta: ok"
  return "$rc"
}

# ---- doc ----
cmd_doc() {
  echo "# Addons"
  echo
  echo "> Gerado de \`kernel/addons/*/addon.meta\` com \`bash kernel/checkpoint/addon_watch.sh doc > docs/ADDONS-LISTA.md\`. **Não edite à mão.**"
  echo
  echo "- **Modo:** \`local\` (código do SAGA), \`vendored-patch\` (cópia de patch do upstream), \`fetch-latest\` (baixa o upstream a cada build, sem fixar versão), \`git-clone\` (clona o upstream a cada build)."
  echo "- **Vigiado:** o Pin Scout avisa por issue quando o upstream muda (\`branch\` = topo da branch; \`path\` = último commit que toca o caminho). \`—\` = não vigiado."
  echo "- **Licença:** do upstream/código de origem; \`?\` = não confirmada (sem arquivo LICENSE ou SPDX)."
  echo
  echo "| Addon | O que faz | Modo | Origem | Licença | Vigiado |"
  echo "|---|---|---|---|---|---|"
  local f name up watch origin
  while IFS= read -r f; do
    name=$(meta_get "$f" name); up=$(meta_get "$f" upstream)
    case "$(meta_get "$f" track)" in none) watch="—" ;; path) watch="caminho \`$(meta_get "$f" track_path)\`" ;; *) watch="branch \`$(meta_get "$f" track_ref)\`" ;; esac
    if [ -n "$up" ]; then origin="[$(slug_of "$up")]($up)"; else origin="SAGA"; fi
    echo "| \`${name}\` | $(meta_get "$f" desc) | $(meta_get "$f" mode) | ${origin} | $(meta_get "$f" license) | ${watch} |"
  done < <(metas)
}

main() {
  case "${1:-check}" in
    check)    shift || true; cmd_check "$@" ;;
    accept)   shift; cmd_accept "$@" ;;
    validate) cmd_validate ;;
    doc)      cmd_doc ;;
    *) echo "uso: $0 check [--report] | accept <addon|all> | validate | doc" >&2; return 2 ;;
  esac
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
