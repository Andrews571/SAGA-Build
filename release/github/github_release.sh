#!/usr/bin/env bash
# ======================================================
# SAGA - Publicar kernel no repo publico de releases
# ======================================================
# Roda no job "publish-kernel-release" do build.yml, DEPOIS que todas as
# variantes terminaram. Pega os zips (AnyKernel3) baixados dos artefatos,
# cria UM release por run e atualiza o "ponteiro" do canal:
#
#   canal estavel       = ADDON_PROFILE Default_Addons  -> ponteiro ptr-stable
#   canal experimental  = ADDON_PROFILE CC_Addons       -> ponteiro ptr-experimental
#
# O app le o saga-release.json do ponteiro (URL fixa):
#   https://github.com/<RELEASES_REPO>/releases/download/ptr-<canal>/saga-release.json
#
# SOMENTE RUN_MODE=Release publica. Build, Warm Run e Dry Run NAO publicam.
#
# Variaveis de entrada (todas vem do build.yml):
#   GH_TOKEN         token com Contents:write no repo de releases (secret SAGA_RELEASES_TOKEN)
#   RELEASES_REPO    ex: Andrews571/SAGA-Releases
#   ZIP_DIR          pasta com os SAGA-*.zip (padrao /tmp/kernels)
#   ADDON_PROFILE    Default_Addons | CC_Addons
#   ADDONS           lista separada por virgula
#   RUN_MODE         Release (qualquer outro valor: nao publica)
#   KERNEL_VERSION   ex: 6.1
#   CHANGELOG        texto livre (opcional)
#   GITHUB_RUN_ID, GITHUB_SHA, GITHUB_REPOSITORY, GITHUB_SERVER_URL

set -euo pipefail

log()  { echo "[saga-release] $*"; }
warn() { echo "::warning::[saga-release] $*"; }

RELEASES_REPO="${RELEASES_REPO:-Andrews571/SAGA-Releases}"
ZIP_DIR="${ZIP_DIR:-/tmp/kernels}"
OUT_DIR="${OUT_DIR:-/tmp/saga-release-out}"

# ------------------------------------------------------
# Somente builds "Release" vao para o SAGA-Releases
# ------------------------------------------------------
if [ "${RUN_MODE:-}" != "Release" ]; then
    log "RUN_MODE='${RUN_MODE:-}': somente 'Release' publica no SAGA-Releases - ignorado"
    exit 0
fi

if [ -z "${GH_TOKEN:-}" ]; then
    warn "SAGA_RELEASES_TOKEN nao configurado - release no GitHub ignorado"
    exit 0
fi

# ------------------------------------------------------
# Garantia: o arquivo publicado TEM que ser o zip do AnyKernel3 da variante.
# - Normal: download-artifact ja entrega o zip do AnyKernel3 (o embrulho .zip
#   do artefato e removido na extracao).
# - Seguranca: se por algum motivo chegar um zip contendo o zip do AnyKernel3
#   (artefato embrulhado), desembrulha. Se nao for AnyKernel3, nao publica.
# ------------------------------------------------------
is_anykernel_zip() {
    local entries
    entries="$(unzip -Z1 "$1" 2>/dev/null)" || return 1
    printf '%s\n' "$entries" | grep -qx 'anykernel.sh' || return 1
    printf '%s\n' "$entries" | grep -qE '^(Image|Image\.gz|Image\.gz-dtb|Image-dtb)$' || return 1
    return 0
}

normalize_zip() {
    local zip="$1" inner count tmp
    if is_anykernel_zip "$zip"; then
        printf '%s\n' "$zip"
        return 0
    fi
    inner="$(unzip -Z1 "$zip" 2>/dev/null | grep -E '\.zip$' || true)"
    count="$(printf '%s\n' "$inner" | grep -c . || true)"
    if [ "$count" = "1" ]; then
        tmp="$OUT_DIR/unwrap"
        rm -rf "$tmp"; mkdir -p "$tmp"
        unzip -q -o "$zip" "$inner" -d "$tmp"
        if is_anykernel_zip "$tmp/$inner"; then
            printf '%s\n' "$tmp/$inner"
            return 0
        fi
    fi
    return 1
}

shopt -s nullglob
ZIPS=("$ZIP_DIR"/SAGA-*.zip)
if [ "${#ZIPS[@]}" -eq 0 ]; then
    warn "nenhum zip em $ZIP_DIR - nada para publicar"
    exit 0
fi

case "${ADDON_PROFILE:-Default_Addons}" in
    CC_Addons) CHANNEL="experimental" ;;
    *)         CHANNEL="stable" ;;
esac

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# ------------------------------------------------------
# 1. Ler os zips: SAGA-<versao>-<variante>-R<run>.zip
# ------------------------------------------------------
VERSION=""
RUN_NO=""
VARIANTS_NDJSON="$OUT_DIR/variants.ndjson"
: > "$VARIANTS_NDJSON"
RECOMMENDED=""
ASSET_FILES=()

for zip in "${ZIPS[@]}"; do
    base="$(basename "$zip")"
    if [[ ! "$base" =~ ^SAGA-([0-9]+\.[0-9]+\.[0-9]+)-(.+)-R([0-9]+)\.zip$ ]]; then
        warn "nome de zip fora do padrao, ignorado: $base"
        continue
    fi
    z_ver="${BASH_REMATCH[1]}"
    variant="${BASH_REMATCH[2]}"
    z_run="${BASH_REMATCH[3]}"

    root="${variant%%+*}"
    susfs=false
    [[ "$variant" == *"+SUSFS" ]] && susfs=true

    # "+" no nome do asset pode ser trocado pelo GitHub; usamos um nome seguro
    asset_name="SAGA-${z_ver}-${variant//+/-}-R${z_run}.zip"

    if ! src_zip="$(normalize_zip "$zip")"; then
        warn "${base} nao e um zip do AnyKernel3 (sem anykernel.sh/Image) - ignorado"
        continue
    fi
    [ "$src_zip" != "$zip" ] && log "${base}: artefato embrulhado, usando o AnyKernel3 de dentro"
    cp "$src_zip" "$OUT_DIR/$asset_name"
    ASSET_FILES+=("$OUT_DIR/$asset_name")

    VERSION="${VERSION:-$z_ver}"
    RUN_NO="${RUN_NO:-$z_run}"

    sha="$(sha256sum "$OUT_DIR/$asset_name" | cut -d' ' -f1)"
    size="$(stat -c%s "$OUT_DIR/$asset_name")"

    jq -n \
        --arg id "$variant" --arg root "$root" --argjson susfs "$susfs" \
        --arg file "$asset_name" --arg sha "$sha" --argjson size "$size" \
        '{id:$id, root:$root, susfs:$susfs, file:$file, sha256:$sha, size:$size}' \
        >> "$VARIANTS_NDJSON"

    # variante recomendada para o app (manager do ramo BakaSU/ReSukiSU)
    if [ "$root" = "RESUKISU" ] && [ "$susfs" = "true" ]; then
        RECOMMENDED="$variant"
    fi
done

if [ "${#ASSET_FILES[@]}" -eq 0 ]; then
    warn "nenhum zip valido - nada para publicar"
    exit 0
fi
[ -n "$RECOMMENDED" ] || RECOMMENDED="$(jq -r '.id' "$VARIANTS_NDJSON" | head -n1)"

TAG="kernel-${CHANNEL}-${VERSION}-R${RUN_NO}"
POINTER="ptr-${CHANNEL}"
BASE_URL="https://github.com/${RELEASES_REPO}/releases/download/${TAG}"
log "canal=${CHANNEL} tag=${TAG} ponteiro=${POINTER} variantes=${#ASSET_FILES[@]}"

# ------------------------------------------------------
# 2. saga-release.json
# ------------------------------------------------------
# kernel.run = numero do build. O mesmo numero aparece no "uname -v" do kernel
# instalado ("#<run> SMP PREEMPT ...", via KBUILD_BUILD_VERSION), e o app usa
# isso para saber qual build esta instalado.
KMI="android14-${KERNEL_VERSION:-6.1}"
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-0}"

jq -s \
    --arg channel "$CHANNEL" \
    --arg profile "${ADDON_PROFILE:-Default_Addons}" \
    --arg version "$VERSION" \
    --arg kmi "$KMI" \
    --argjson run "${RUN_NO:-0}" \
    --arg built_at "$BUILT_AT" \
    --arg commit "${GITHUB_SHA:-}" \
    --arg run_url "$RUN_URL" \
    --arg addons "${ADDONS:-}" \
    --arg changelog "${CHANGELOG:-}" \
    --arg base "$BASE_URL" \
    --arg recommended "$RECOMMENDED" \
    '{
        schema: 1,
        channel: $channel,
        profile: $profile,
        kernel: { name: "SAGA", version: $version, kmi: $kmi, run: $run,
                  built_at: $built_at, commit: $commit, run_url: $run_url },
        addons: ($addons | split(",") | map(select(length > 0))),
        changelog: $changelog,
        recommended: $recommended,
        variants: (map(. + { url: ($base + "/" + .file) }))
    }' "$VARIANTS_NDJSON" > "$OUT_DIR/saga-release.json"

log "saga-release.json:"
cat "$OUT_DIR/saga-release.json"

# ------------------------------------------------------
# 3. Notas do release (texto para humanos)
# ------------------------------------------------------
{
    echo "SAGA ${VERSION} - canal **${CHANNEL}** (${ADDON_PROFILE:-Default_Addons})"
    echo
    echo "Arquivos (AnyKernel3):"
    jq -r '.variants[] | "- `\(.file)`  sha256 `\(.sha256)`"' "$OUT_DIR/saga-release.json"
    echo
    echo "Addons: ${ADDONS:-nenhum}"
    if [ -n "${CHANGELOG:-}" ]; then
        echo
        echo "Changelog:"
        echo "${CHANGELOG}"
    fi
    echo
    echo "Build: ${RUN_URL}"
} > "$OUT_DIR/notes.md"

# ------------------------------------------------------
# 4. Publicar
# ------------------------------------------------------
if gh release view "$TAG" --repo "$RELEASES_REPO" >/dev/null 2>&1; then
    log "release ${TAG} ja existe - atualizando arquivos"
    gh release upload "$TAG" "${ASSET_FILES[@]}" "$OUT_DIR/saga-release.json" \
        --repo "$RELEASES_REPO" --clobber
else
    gh release create "$TAG" "${ASSET_FILES[@]}" "$OUT_DIR/saga-release.json" \
        --repo "$RELEASES_REPO" \
        --title "SAGA ${VERSION} (${CHANNEL}) R${RUN_NO}" \
        --notes-file "$OUT_DIR/notes.md" \
        --latest=false
fi

# Ponteiro do canal: URL fixa, sempre com o saga-release.json mais novo
if ! gh release view "$POINTER" --repo "$RELEASES_REPO" >/dev/null 2>&1; then
    gh release create "$POINTER" \
        --repo "$RELEASES_REPO" \
        --prerelease --latest=false \
        --title "${POINTER} (automatico)" \
        --notes "Ponteiro do canal ${CHANNEL}, lido pelo SAGA App. Nao apagar."
fi
gh release upload "$POINTER" "$OUT_DIR/saga-release.json" \
    --repo "$RELEASES_REPO" --clobber

log "publicado: https://github.com/${RELEASES_REPO}/releases/tag/${TAG}"
