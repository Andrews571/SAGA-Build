#!/usr/bin/env bash

# ======================================================
# 🔤 ADDON — Unicode normalization bypass fix (SAGA)
# ======================================================
# fs/unicode/utf8-norm.c: rejeita decomposição vazia ANTES de mudar
# de estado no laço de utf8byte(), fechando um bypass de normalização
# Unicode. Puxado ao vivo do WildKernels/kernel_patches (mesmo repo
# de onde já vêm o BBRv3 e o NTSync de vocês), variante 6.1+.
#
# Verificado contra android14-6.1-live: aplica limpo, sem fuzz, sem
# adaptação necessária -- o trecho bate linha por linha com o
# arquivo de vocês.

PATCH_URL="https://raw.githubusercontent.com/WildKernels/kernel_patches/main/common/unicode_bypass_fix_6.1%2B.patch"
PATCH_FILE="${ROOT_DIR}/unicode_bypass_fix_6.1+.patch"

log "🔤 Fetching Unicode normalization bypass fix..."
curl -sL -o "$PATCH_FILE" "$PATCH_URL" || error "UNICODE_FIX: download failed!"

if [ ! -s "$PATCH_FILE" ]; then
    error "UNICODE_FIX: downloaded patch is empty, aborting!"
fi

log "🔤 Applying Unicode normalization bypass fix..."
cd "${KERNEL_SRC}"

if patch -p1 --fuzz=3 --dry-run --reverse < "$PATCH_FILE" > /dev/null 2>&1; then
    log "UNICODE_FIX: already applied, skipping."
elif patch -p1 --fuzz=3 --dry-run --forward < "$PATCH_FILE" > /dev/null 2>&1; then
    patch -p1 --fuzz=3 --forward < "$PATCH_FILE" || error "UNICODE_FIX: apply failed!"
    log "UNICODE_FIX: applied ✅"
else
    error "UNICODE_FIX: does not apply cleanly against fs/unicode/utf8-norm.c — upstream ou seu tree mudou desde a última checagem!"
fi

cd "${ROOT_DIR}"
rm -f "$PATCH_FILE"
log "Unicode normalization bypass fix integrated ✅"
