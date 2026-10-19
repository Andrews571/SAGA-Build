#!/usr/bin/env bash
# ======================================================
# SAGA - Manager Signature (SAGA-App)
# ======================================================
# Embute no kernel o certificado do SAGA-App, para o kernel
# reconhecer o app como root manager automaticamente.
#
# Como funciona: o Kbuild do BakaSU/ReSukiSU tem um slot "Custom"
# que le duas variaveis de ambiente na hora do build:
#   KSU_EXPECTED_SIZE  (tamanho do certificado, ex: 0x0582)
#   KSU_EXPECTED_HASH  (SHA-256 do certificado)
# Este script define as duas. Os valores vem do update.json do
# ultimo release do SAGA-App; se nao der para baixar, usa o fallback.
#
# Este arquivo e carregado com "source" pelo build.sh (run_core),
# depois que o root solution ja foi aplicado ao kernel.

if [ "${KERNEL_VARIANT:-}" = "VANILLA" ]; then
    log "Manager signature: build VANILLA (sem root) - ignorando"
    return 0
fi

SAGA_APP_REPO="${SAGA_APP_REPO:-Andrews571/SAGA-App}"

# Fallback = certificado do app-v0.1.0
SAGA_APP_FALLBACK_SIZE="0x0582"
SAGA_APP_FALLBACK_HASH="67c93fb925566196354154f8285aa03f85f208d00f5899147b1c6c578c43ee84"

_saga_size=""
_saga_hash=""

_saga_json="$(curl -fsSL --retry 3 --connect-timeout 10 \
    "https://github.com/${SAGA_APP_REPO}/releases/latest/download/update.json" 2>/dev/null || true)"

if [ -n "$_saga_json" ]; then
    _saga_size="$(printf '%s' "$_saga_json" | jq -r '.cert_size // empty' 2>/dev/null || true)"
    _saga_hash="$(printf '%s' "$_saga_json" | jq -r '.cert_sha256 // empty' 2>/dev/null || true)"
fi

if [[ "$_saga_size" =~ ^0x[0-9a-fA-F]{3,4}$ ]] && [[ "$_saga_hash" =~ ^[0-9a-f]{64}$ ]]; then
    log "Manager signature: valores lidos do update.json do SAGA-App"
else
    warn "Manager signature: nao consegui ler o update.json - usando fallback (app-v0.1.0)"
    _saga_size="$SAGA_APP_FALLBACK_SIZE"
    _saga_hash="$SAGA_APP_FALLBACK_HASH"
fi

export KSU_EXPECTED_SIZE="$_saga_size"
export KSU_EXPECTED_HASH="$_saga_hash"

log "Manager signature: size=${KSU_EXPECTED_SIZE} hash=${KSU_EXPECTED_HASH}"

# Confere se o Kbuild do root solution aplicado suporta o slot Custom.
# Se nao suportar, o app NAO sera reconhecido (o build continua, mas avisa).
if ! grep -RqsE --include=Kbuild "KSU_EXPECTED_SIZE" \
        "${KERNEL_SRC}/drivers" "${KERNEL_SRC}/KernelSU" 2>/dev/null; then
    warn "Manager signature: Kbuild do root solution nao menciona KSU_EXPECTED_SIZE - o SAGA-App pode nao ser reconhecido por este kernel"
fi

unset _saga_json _saga_size _saga_hash
