import sys

MARKER = "SAGA: force MGLRU on (core-only test)"

# --- Anchor 1: request only CORE on write --------------------------------
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
    "\t/* " + MARKER + ": force CORE only. MM_WALK/NONLEAF_YOUNG are\n"
    "\t * deliberately NOT forced here — this build exists to isolate\n"
    "\t * whether a reclaim deadlock seen on this device comes from basic\n"
    "\t * generation eviction (CORE) or from the active page-table walk\n"
    "\t * (MM_WALK/NONLEAF_YOUNG). Do not add those bits back until CORE\n"
    "\t * alone has been confirmed stable.\n"
    "\t */\n"
    "\tcaps |= BIT(LRU_GEN_CORE);\n"
    "\n"
    "\tfor (i = 0; i < NR_LRU_GEN_CAPS; i++) {"
)

# --- Anchor 2: leave lru_gen_change_state() untouched, no hardcode -------
# With only CORE forced above, `enabled` for i == LRU_GEN_CORE is always
# true anyway (the bit is always present in caps), so no change is needed
# here — kept as a no-op anchor check purely to fail loud if upstream
# refactors this function, same as the other patch variants.
STATE_ANCHOR = (
    "\t\tif (i == LRU_GEN_CORE)\n"
    "\t\t\tlru_gen_change_state(enabled);"
)


def apply(content, anchor, replacement, label):
    if anchor not in content:
        return content, False, label
    return content.replace(anchor, replacement, 1), True, None


def main():
    if len(sys.argv) < 2:
        print("[error] usage: patch_core_only.py <vmscan.c>", flush=True)
        sys.exit(1)

    path = sys.argv[1]
    with open(path, "r") as f:
        content = f.read()

    if MARKER in content:
        print("[info] mglru_force_enable: already patched (core-only) — skipping", flush=True)
        sys.exit(0)

    if "luminaire: force MGLRU on" in content and MARKER not in content:
        print(
            "[error] mglru_force_enable: a different mglru patch variant is "
            "already applied — revert it first, this version is not meant "
            "to stack on top of it",
            flush=True,
        )
        sys.exit(1)

    content, ok1, why1 = apply(content, CAPS_ANCHOR, CAPS_REPLACEMENT, "caps anchor")
    _, ok2, why2 = apply(content, STATE_ANCHOR, "", "state anchor (presence check only)")

    if not ok1 or not ok2:
        missing = [w for w in (why1, why2) if w]
        print(
            "[warn] mglru_force_enable: " + ", ".join(missing) +
            " not found in expected form — upstream may have refactored "
            "store_enabled(). Skipping MGLRU patch, build continues without it.",
            flush=True,
        )
        sys.exit(0)

    with open(path, "w") as f:
        f.write(content)

    print(
        "[info] mglru_force_enable: CORE-ONLY test patch applied — "
        "MM_WALK/NONLEAF_YOUNG left untouched (whatever this kernel's "
        "default is) ✅",
        flush=True,
    )


if __name__ == "__main__":
    main()
