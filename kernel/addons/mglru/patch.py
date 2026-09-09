import sys

MARKER = "luminaire: force MGLRU on (adaptive)"

# --- Anchor 1: request all caps on write --------------------------------
CAPS_ANCHOR = (
    "\telse if (kstrtouint(buf, 0, &caps))\n"
    "\t\treturn -EINVAL;\n"
    "\n"
    "\tfor (i = 0; i < NR_LRU_GEN_CAPS; i++) {"
)
CAPS_REPLACEMENT = (
    "\telse if (kstrtouint(buf, 0, &caps))\n"
    "\t\treturn -EINVAL;\n"
    "\n"
    "\t/* " + MARKER + ": always *request* every cap. Whether each\n"
    "\t * one actually gets turned on is decided per-bit below, mirroring\n"
    "\t * show_enabled()'s arch_has_hw_*() gating — we never enable a\n"
    "\t * capability the running hardware doesn't support.\n"
    "\t */\n"
    "\tcaps |= BIT(LRU_GEN_CORE) | BIT(LRU_GEN_MM_WALK) | BIT(LRU_GEN_NONLEAF_YOUNG);\n"
    "\n"
    "\tfor (i = 0; i < NR_LRU_GEN_CAPS; i++) {"
)

# --- Anchor 2: per-bit hw gating (THIS is the fix for the bootloop) ----
# store_enabled() has ZERO hardware validation, unlike show_enabled().
# Forcing MM_WALK/NONLEAF_YOUNG bits without checking arch_has_hw_*()
# flips static branches for code paths the SoC/kernel may not support
# -> invalid pgtable walk very early in the reclaim path (kswapd) ->
# panic before UI -> bootloop. Fix: gate each bit exactly like
# show_enabled() does, so unsupported hw silently stays off instead of
# crashing.
GATE_ANCHOR = (
    "\tfor (i = 0; i < NR_LRU_GEN_CAPS; i++) {\n"
    "\t\tbool enabled = caps & BIT(i);\n"
    "\n"
    "\t\tif (i == LRU_GEN_CORE)"
)
GATE_REPLACEMENT = (
    "\tfor (i = 0; i < NR_LRU_GEN_CAPS; i++) {\n"
    "\t\tbool enabled = caps & BIT(i);\n"
    "\n"
    "\t\t/* " + MARKER + ": per-bit hw gate, same source of truth as\n"
    "\t\t * show_enabled(). Never enable a cap the hardware can't do.\n"
    "\t\t */\n"
    "\t\tif (i == LRU_GEN_MM_WALK)\n"
    "\t\t\tenabled = enabled && arch_has_hw_pte_young();\n"
    "\t\telse if (i == LRU_GEN_NONLEAF_YOUNG)\n"
    "\t\t\tenabled = enabled && arch_has_hw_nonleaf_pmd_young();\n"
    "\n"
    "\t\tif (i == LRU_GEN_CORE)"
)


def apply(content, anchor, replacement, label):
    if anchor not in content:
        return content, False, label
    return content.replace(anchor, replacement, 1), True, None


def main():
    if len(sys.argv) < 2:
        print("[error] usage: patch_v3.py <vmscan.c>", flush=True)
        sys.exit(1)

    path = sys.argv[1]
    with open(path, "r") as f:
        content = f.read()

    if MARKER in content:
        print("[info] mglru_force_enable: already patched (adaptive) — skipping", flush=True)
        sys.exit(0)

    if "luminaire: force MGLRU on" in content and MARKER not in content:
        print(
            "[error] mglru_force_enable: legacy hardcoded patch detected — "
            "revert it first, this version is not meant to stack on it",
            flush=True,
        )
        sys.exit(1)

    content, ok1, why1 = apply(content, CAPS_ANCHOR, CAPS_REPLACEMENT, "caps anchor")
    content, ok2, why2 = apply(content, GATE_ANCHOR, GATE_REPLACEMENT, "hw-gate anchor")

    if not ok1 or not ok2:
        missing = [w for w in (why1, why2) if w]
        print(
            "[warn] mglru_force_enable: " + ", ".join(missing) +
            " not found in expected form — upstream may have refactored "
            "store_enabled(). Skipping MGLRU patch, build continues without it.",
            flush=True,
        )
        # Non-fatal on purpose: treat shape mismatch as "unavailable",
        # not a build breaker. Flip to sys.exit(1) if you'd rather fail loud.
        sys.exit(0)

    with open(path, "w") as f:
        f.write(content)

    print(
        "[info] mglru_force_enable: adaptive patch applied — CORE always on, "
        "MM_WALK/NONLEAF_YOUNG requested but only enabled where hardware "
        "actually supports them ✅",
        flush=True,
    )


if __name__ == "__main__":
    main()
