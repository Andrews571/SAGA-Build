#!/usr/bin/env bash

# ======================================================
# 🔤 COMPILER STRING — SANITIZE UTS VERSION
# ======================================================

MKCOMPILE_H="${KERNEL_SRC}/scripts/mkcompile_h"

[ -f "$MKCOMPILE_H" ] || { warn "mkcompile_h not found, skipping compiler string patch"; return 0; }

python3 - "$MKCOMPILE_H" << 'PYEOF'
import sys, re

path = sys.argv[1]

with open(path, "r") as f:
    content = f.read()

# mkcompile_h structure in GKI android14-6.1:
#   CC_VERSION="$2"   (passed from kernel Makefile — already clean via KBUILD_COMPILER_STRING)
#   LD_VERSION=$(LC_ALL=C $LD -v | head -n1 | sed ...)
#   #define LINUX_COMPILER "${CC_VERSION}, ${LD_VERSION}"
#
# KBUILD_COMPILER_STRING in MAKE_ARGS controls CC_VERSION correctly (clean name + version).
# LD_VERSION reads raw "ld.lld -v" output which includes a full LLVM commit URL.
# We replace the LD_VERSION command substitution block with a clean extraction:
#   run the original command, then strip everything except "LLD X.Y.Z".
#
# Result: LINUX_COMPILER = "Cirrus Clang 23.0.0, LLD 23.0.0"
#
# LD_VERSION uses a multiline command substitution with nested parens inside sed,
# so we track paren depth line-by-line to find the exact closing ) cleanly.

lines = content.split('\n')
out = []
i = 0
replaced = False

clean_ld = (
    'LD_VERSION=$(LC_ALL=C $LD -v 2>/dev/null | head -n1 | '
    "grep -oP 'LLD\\s+\\K[0-9]+\\.[0-9]+\\.[0-9]+' | "
    "head -n1 | sed 's/^/LLD /')"
)

while i < len(lines):
    line = lines[i]
    if not replaced and re.match(r'\s*LD_VERSION=\$\(', line):
        depth = 0
        j = i
        while j < len(lines):
            for ch in lines[j]:
                if ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
            if depth <= 0:
                break
            j += 1
        out.append(clean_ld)
        i = j + 1
        replaced = True
        continue
    out.append(line)
    i += 1

if not replaced:
    print("[warn] compiler_string.sh: LD_VERSION block not found in mkcompile_h, file unchanged", flush=True)
    sys.exit(0)

with open(path, "w") as f:
    f.write('\n'.join(out))

print("[info] mkcompile_h: LD_VERSION sanitized to 'LLD X.Y.Z' ✅", flush=True)
PYEOF

log "Compiler string patched in mkcompile_h ✅"
