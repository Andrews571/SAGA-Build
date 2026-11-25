import sys

# MGLRU v2 (SAGA) — liga o MGLRU TARDE e ignora o "echo 0" da ROM.
#
# Por que: a ColorOS roda `echo 0 > /sys/kernel/mm/lru_gen/enabled` em
# post-fs-data (init.oplus.nandswap.sh, ~11 s de boot). A v1 transformava
# esse `0` em "liga o CORE" no meio do init (bootloop). Aqui:
#   1) o kernel liga o MGLRU completo (como 'y') SAGA_MGLRU_DELAY_S segundos
#      depois do late_initcall, quando o init/boot_completed ja passou;
#   2) escrita numerica 0 vinda do userspace e IGNORADA (e logada);
#      'n' continua desligando e fica "sticky" (cancela a ativacao tardia);
#   3) toda escrita em `enabled` e logada (valor, processo, pid).
MARKER = "SAGA: MGLRU v2"

OLD_STORE = (
    "/* see Documentation/admin-guide/mm/multigen_lru.rst for details */\n"
    "static ssize_t store_enabled(struct kobject *kobj, struct kobj_attribute *attr,\n"
    "\t\t\t     const char *buf, size_t len)\n"
    "{\n"
    "\tint i;\n"
    "\tunsigned int caps;\n"
    "\n"
    "\tif (tolower(*buf) == 'n')\n"
    "\t\tcaps = 0;\n"
    "\telse if (tolower(*buf) == 'y')\n"
    "\t\tcaps = -1;\n"
    "\telse if (kstrtouint(buf, 0, &caps))\n"
    "\t\treturn -EINVAL;\n"
    "\n"
    "\tfor (i = 0; i < NR_LRU_GEN_CAPS; i++) {\n"
    "\t\tbool enabled = caps & BIT(i);\n"
    "\n"
    "\t\tif (i == LRU_GEN_CORE)\n"
    "\t\t\tlru_gen_change_state(enabled);\n"
    "\t\telse if (enabled)\n"
    "\t\t\tstatic_branch_enable(&lru_gen_caps[i]);\n"
    "\t\telse\n"
    "\t\t\tstatic_branch_disable(&lru_gen_caps[i]);\n"
    "\t}\n"
    "\n"
    "\treturn len;\n"
    "}\n"
)

NEW_STORE = (
    "/* " + MARKER + ": delayed enable + ignore userspace numeric 0 */\n"
    "#define SAGA_MGLRU_DELAY_S\t90\n"
    "\n"
    "static bool saga_mglru_user_off;\t/* 'n' written: cancel delayed enable */\n"
    "\n"
    "static void saga_mglru_apply_caps(unsigned int caps)\n"
    "{\n"
    "\tint i;\n"
    "\n"
    "\tfor (i = 0; i < NR_LRU_GEN_CAPS; i++) {\n"
    "\t\tbool enabled = caps & BIT(i);\n"
    "\n"
    "\t\tif (i == LRU_GEN_CORE)\n"
    "\t\t\tlru_gen_change_state(enabled);\n"
    "\t\telse if (enabled)\n"
    "\t\t\tstatic_branch_enable(&lru_gen_caps[i]);\n"
    "\t\telse\n"
    "\t\t\tstatic_branch_disable(&lru_gen_caps[i]);\n"
    "\t}\n"
    "}\n"
    "\n"
    "static void saga_mglru_delayed_enable(struct work_struct *work)\n"
    "{\n"
    "\tif (READ_ONCE(saga_mglru_user_off)) {\n"
    "\t\tpr_info(\"saga-mglru: delayed enable skipped (userspace wrote 'n')\\n\");\n"
    "\t\treturn;\n"
    "\t}\n"
    "\tsaga_mglru_apply_caps(-1);\t/* same as writing 'y' */\n"
    "\tpr_info(\"saga-mglru: enabled after %ds delay, caps=0x%04x\\n\", SAGA_MGLRU_DELAY_S,\n"
    "\t\t(unsigned int)((get_cap(LRU_GEN_CORE) ? BIT(LRU_GEN_CORE) : 0) |\n"
    "\t\t\t(arch_has_hw_pte_young() && get_cap(LRU_GEN_MM_WALK) ? BIT(LRU_GEN_MM_WALK) : 0) |\n"
    "\t\t\t(arch_has_hw_nonleaf_pmd_young() && get_cap(LRU_GEN_NONLEAF_YOUNG) ? BIT(LRU_GEN_NONLEAF_YOUNG) : 0)));\n"
    "}\n"
    "static DECLARE_DELAYED_WORK(saga_mglru_enable_work, saga_mglru_delayed_enable);\n"
    "\n"
    "/* see Documentation/admin-guide/mm/multigen_lru.rst for details */\n"
    "static ssize_t store_enabled(struct kobject *kobj, struct kobj_attribute *attr,\n"
    "\t\t\t     const char *buf, size_t len)\n"
    "{\n"
    "\tunsigned int caps;\n"
    "\tint vis = (int)strcspn(buf, \"\\n\");\n"
    "\n"
    "\tif (vis > 16)\n"
    "\t\tvis = 16;\n"
    "\n"
    "\tif (tolower(*buf) == 'n') {\n"
    "\t\tcaps = 0;\n"
    "\t\tWRITE_ONCE(saga_mglru_user_off, true);\n"
    "\t} else if (tolower(*buf) == 'y') {\n"
    "\t\tcaps = -1;\n"
    "\t\tWRITE_ONCE(saga_mglru_user_off, false);\n"
    "\t} else if (kstrtouint(buf, 0, &caps)) {\n"
    "\t\treturn -EINVAL;\n"
    "\t}\n"
    "\n"
    "\t/* ROM init scripts (ColorOS nandswap) do `echo 0`: ignore it. */\n"
    "\tif (!caps && tolower(*buf) != 'n') {\n"
    "\t\tpr_info(\"saga-mglru: ignored userspace write '%.*s' by %s[%d] (use 'n' to disable)\\n\",\n"
    "\t\t\tvis, buf, current->comm, task_pid_nr(current));\n"
    "\t\treturn len;\n"
    "\t}\n"
    "\n"
    "\tpr_info(\"saga-mglru: write '%.*s' by %s[%d]\\n\",\n"
    "\t\tvis, buf, current->comm, task_pid_nr(current));\n"
    "\tsaga_mglru_apply_caps(caps);\n"
    "\n"
    "\treturn len;\n"
    "}\n"
)

OLD_INIT = (
    "\tdebugfs_create_file(\"lru_gen_full\", 0444, NULL, NULL, &lru_gen_ro_fops);\n"
    "\n"
    "\treturn 0;\n"
    "};\n"
    "late_initcall(init_lru_gen);\n"
)
NEW_INIT = (
    "\tdebugfs_create_file(\"lru_gen_full\", 0444, NULL, NULL, &lru_gen_ro_fops);\n"
    "\n"
    "\t/* " + MARKER + ": turn MGLRU on once boot has settled */\n"
    "\tschedule_delayed_work(&saga_mglru_enable_work, SAGA_MGLRU_DELAY_S * HZ);\n"
    "\n"
    "\treturn 0;\n"
    "};\n"
    "late_initcall(init_lru_gen);\n"
)


def main():
    if len(sys.argv) < 2:
        print("[error] usage: patch.py <vmscan.c>", flush=True)
        sys.exit(1)
    path = sys.argv[1]
    content = open(path).read()

    if MARKER in content:
        print("[info] mglru v2: already patched — skipping", flush=True)
        sys.exit(0)
    if "SAGA: force MGLRU on (core-only test)" in content or "luminaire: force MGLRU on" in content:
        print("[error] mglru v2: an older mglru patch variant is applied — start from a clean tree", flush=True)
        sys.exit(1)

    if OLD_STORE not in content or OLD_INIT not in content:
        print("[warn] mglru v2: store_enabled()/init_lru_gen() not in the expected form — "
              "upstream may have refactored. Skipping MGLRU patch, build continues without it.", flush=True)
        sys.exit(0)

    content = content.replace(OLD_STORE, NEW_STORE, 1).replace(OLD_INIT, NEW_INIT, 1)
    open(path, "w").write(content)
    print("[info] mglru v2: delayed enable (%ds) + ignore userspace '0' + write log ✅" % 90, flush=True)


if __name__ == "__main__":
    main()
