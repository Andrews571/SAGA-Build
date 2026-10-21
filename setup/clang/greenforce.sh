#!/usr/bin/env bash

# ======================================================
# 🧰 CLANG VARIANT — Greenforce (greenforce-project/greenforce_clang)
# ======================================================
# Rolling LLVM trunk build (self-identifies as "Cirrus clang"). Requires
# glibc >= 2.34 on the host (ubuntu-24.04 runner is fine).
#
# URL comes from the repo's own get_latest_url.sh (plain raw file, parsed —
# never sourced) instead of api.github.com: no unauthenticated API rate
# limit. Falls back to the releases API if the raw file is unavailable.

log "Downloading Greenforce Clang..."

GF_URL=$(curl -fsSL https://raw.githubusercontent.com/greenforce-project/greenforce_clang/refs/heads/main/get_latest_url.sh 2>/dev/null \
    | sed -n 's/^LATEST_URL=//p' | head -1 | tr -d "\"'\r") || GF_URL=""

if [ -z "$GF_URL" ]; then
    warn "Greenforce: get_latest_url.sh unavailable — falling back to releases API"
    GF_URL=$(curl -fsSL https://api.github.com/repos/greenforce-project/greenforce_clang/releases/latest \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((x['browser_download_url'] for x in d.get('assets',[]) if x['name'].endswith('.tar.gz')), ''))") \
        || error "Greenforce: failed to query GitHub API!"
fi
[ -n "$GF_URL" ] || error "Greenforce: could not resolve a download URL!"

retry 3 run_quiet curl -fL "$GF_URL" -o /tmp/clang.tar.gz \
    || error "Greenforce: download failed!"
# Tarball root is ./bin ./lib (the leading "." is the 1 stripped component)
tar -xf /tmp/clang.tar.gz -C "$TOOL_CLANG_DIR" --strip-components=1
rm -f /tmp/clang.tar.gz
log "Greenforce Clang downloaded ✅"
