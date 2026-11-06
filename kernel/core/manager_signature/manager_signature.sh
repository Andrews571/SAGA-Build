#!/usr/bin/env bash
# ======================================================
# SAGA - Manager Signature (SAGA-App)
# ======================================================
# Embute no kernel o certificado do SAGA-App, para o kernel
# reconhecer o app como root manager automaticamente.
#
# Como funciona: o Kbuild do BakaSU/ReSukiSU tem um slot "Custom"
# que le duas variaveis de ambiente na hora do build:
#   KSU_EXPECTED_SIZE  (tamanho do certificado, ex: 0x0382)
#   KSU_EXPECTED_HASH  (SHA-256 do certificado)
# Este script define as duas, lendo o update.json do ponteiro
# "ptr-app" do repo publico de releases (com fallback para o repo do app).
#
# LIMITE IMPORTANTE: o kernel so le certificados de ate 1024 bytes
# (CERT_MAX_LENGTH em apk_sign.c). Chave RSA 4096 gera certificado de
# ~1410 bytes e NUNCA e reconhecida. Use RSA 2048 (~800-900 bytes).
#
# Este arquivo e carregado com "source" pelo build.sh (run_core),
# depois que o root solution ja foi aplicado ao kernel.

if [ "${KERNEL_VARIANT:-}" = "VANILLA" ]; then
    log "Manager signature: build VANILLA (sem root) - ignorando"
    return 0
fi

# Repo publico de releases (ponteiro "ptr-app" sempre aponta para o update.json mais novo)
SAGA_RELEASES_REPO="${SAGA_RELEASES_REPO:-Andrews571/SAGA-Releases}"
# Compatibilidade: release antigo no repo do app (so funciona enquanto ele for publico)
SAGA_APP_REPO="${SAGA_APP_REPO:-Andrews571/SAGA-App}"
SAGA_CERT_MAX_BYTES=1024

_saga_size=""
_saga_hash=""

_saga_json="$(curl -fsSL --retry 3 --connect-timeout 10 \
    "https://github.com/${SAGA_RELEASES_REPO}/releases/download/ptr-app/update.json" 2>/dev/null || true)"
if [ -z "$_saga_json" ]; then
    _saga_json="$(curl -fsSL --retry 3 --connect-timeout 10 \
        "https://github.com/${SAGA_APP_REPO}/releases/latest/download/update.json" 2>/dev/null || true)"
fi

if [ -n "$_saga_json" ]; then
    _saga_size="$(printf '%s' "$_saga_json" | jq -r '.cert_size // empty' 2>/dev/null || true)"
    _saga_hash="$(printf '%s' "$_saga_json" | jq -r '.cert_sha256 // empty' 2>/dev/null || true)"
fi

if ! [[ "$_saga_size" =~ ^0x[0-9a-fA-F]{3,4}$ ]] || ! [[ "$_saga_hash" =~ ^[0-9a-f]{64}$ ]]; then
    warn "Manager signature: nao consegui ler o update.json do SAGA-App - kernel compilado SEM o certificado do app"
    unset _saga_json _saga_size _saga_hash _saga_kbuilds _saga_supported _f
    return 0
fi

if [ $((_saga_size)) -gt "$SAGA_CERT_MAX_BYTES" ]; then
    warn "Manager signature: certificado do app tem $((_saga_size)) bytes (> ${SAGA_CERT_MAX_BYTES}) - o kernel nao consegue le-lo. Gere o keystore com RSA 2048. Ignorando."
    unset _saga_json _saga_size _saga_hash
    return 0
fi

log "Manager signature: valores lidos do update.json do SAGA-App"

export KSU_EXPECTED_SIZE="$_saga_size"
export KSU_EXPECTED_HASH="$_saga_hash"

log "Manager signature: size=${KSU_EXPECTED_SIZE} hash=${KSU_EXPECTED_HASH}"

# KernelSU-Next (variante KSUNEXT) NAO le KSU_EXPECTED_*: ele aceita uma lista
# "tamanho:hash,tamanho:hash" (KSU_NEXT_MANAGER_LIST) que, por padrao, so tem os managers
# dele. Acrescentamos o SAGA mantendo os padroes, para o manager oficial continuar valendo.
_saga_kbuilds=(
    "${KERNEL_SRC}/drivers/kernelsu/Kbuild"
    "${KERNEL_SRC}/KernelSU-Next/kernel/Kbuild"
    "${KERNEL_SRC}/KernelSU/kernel/Kbuild"
)
_next_kbuild=""
for _f in "${_saga_kbuilds[@]}"; do
    if [ -f "$_f" ] && grep -qE '^[[:space:]]*KSU_NEXT_MANAGER_LIST[[:space:]]*:?=' "$_f"; then
        _next_kbuild="$_f"
        break
    fi
done
if [ -n "$_next_kbuild" ]; then
    _next_default="$(sed -n 's/^[[:space:]]*KSU_NEXT_MANAGER_LIST[[:space:]]*:\{0,1\}=[[:space:]]*//p' \
        "$_next_kbuild" | head -n1 | tr -d '[:space:]')"
    if [ -z "$_next_default" ]; then
        warn "Manager signature: nao consegui ler a lista padrao do KernelSU-Next - usando a lista conhecida"
        _next_default="0x3e6:79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7,0x338:f26471a28031130362bce7eebffb9a0b8afc3095f163ce0c75a309f03b644a1f"
    fi
    _saga_entry="${KSU_EXPECTED_SIZE}:${KSU_EXPECTED_HASH}"
    case ",${_next_default}," in
        *",${_saga_entry},"*) export KSU_NEXT_MANAGER_LIST="$_next_default" ;;
        *)                    export KSU_NEXT_MANAGER_LIST="${_next_default},${_saga_entry}" ;;
    esac
    log "Manager signature: KernelSU-Next - chave do SAGA acrescentada a lista de managers"
    log "Manager signature: KSU_NEXT_MANAGER_LIST=${KSU_NEXT_MANAGER_LIST}"
    unset _next_kbuild _next_default _saga_entry
fi

# Confere se o Kbuild do root solution aplicado suporta o slot Custom.
_saga_supported=false
for _f in "${_saga_kbuilds[@]}"; do
    if [ -f "$_f" ] && grep -qE "KSU_EXPECTED_SIZE|KSU_NEXT_MANAGER_LIST" "$_f"; then
        _saga_supported=true
        break
    fi
done
if [ "$_saga_supported" != "true" ]; then
    warn "Manager signature: o root solution aplicado nao menciona KSU_EXPECTED_SIZE nem KSU_NEXT_MANAGER_LIST - o SAGA-App pode nao ser reconhecido por este kernel"
fi

unset _saga_json _saga_size _saga_hash _saga_kbuilds _saga_supported _f
