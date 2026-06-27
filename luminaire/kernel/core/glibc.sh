#!/usr/bin/env bash

# ======================================================
# 🔧 GLIBC >= 2.38
# ======================================================

GLIBC_VERSION="$(ldd --version 2>/dev/null | head -n 1 | awk '{print $NF}')"
if [ "$(printf '%s\n' "2.38" "$GLIBC_VERSION" | sort -V | head -n 1)" = "2.38" ]; then
    log "Applying GLIBC >= 2.38 fix..."
    BTFIDS_MK="${KERNEL_DIR}/common/tools/bpf/resolve_btfids/Makefile"

    if [ ! -f "$BTFIDS_MK" ]; then
        warn "GLIBC fix: resolve_btfids/Makefile not found at expected path — upstream may have moved it; skipping"
    else
        PATTERN='$(Q)$(MAKE) -C $(SUBCMD_SRC) OUTPUT=$(abspath $(dir $@))/ $(abspath $@)'
        if ! grep -qF "$PATTERN" "$BTFIDS_MK"; then
            if grep -qF 'EXTRA_CFLAGS="$(CFLAGS)"' "$BTFIDS_MK"; then
                log "GLIBC fix already applied, skipping ✅"
            else
                error "GLIBC fix: pattern not found in resolve_btfids/Makefile — kernel source may have changed upstream. Fix needs update!"
            fi
        else
            sed -i 's/$(Q)$(MAKE) -C $(SUBCMD_SRC) OUTPUT=$(abspath $(dir $@))\/  $(abspath $@)/$(Q)$(MAKE) -C $(SUBCMD_SRC) EXTRA_CFLAGS="$(CFLAGS)" OUTPUT=$(abspath $(dir $@))\/ $(abspath $@)/' \
                "$BTFIDS_MK"
            log "GLIBC fix applied ✅"
        fi
    fi
else
    log "GLIBC < 2.38 detected, fix not needed ✅"
fi
