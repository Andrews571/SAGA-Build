import sys


def main():
    path = sys.argv[1]

    with open(path, "r") as f:
        lines = f.readlines()

    in_lsm_block = False
    lsm_start = None

    for i, line in enumerate(lines):
        if line.strip() == "config LSM":
            in_lsm_block = True
            lsm_start = i
            continue

        if in_lsm_block:
            if line.startswith("help"):
                in_lsm_block = False
                continue

            stripped = line.strip()
            if stripped.startswith("default"):
                if "baseband_guard" in stripped:
                    print("[info] bbg_kconfig_inject: baseband_guard already present — skipping")
                    sys.exit(0)

                if "selinux" in stripped:
                    lines[i] = line.replace("selinux", "selinux,baseband_guard", 1)
                    with open(path, "w") as f:
                        f.writelines(lines)
                    print(f"[info] bbg_kconfig_inject: injected baseband_guard at line {i + 1} ✅")
                    sys.exit(0)
                else:
                    print(f"[warn] bbg_kconfig_inject: default line found but no 'selinux' anchor — skipping")
                    sys.exit(0)

    print(f"[warn] bbg_kconfig_inject: 'config LSM' block not found in {path} — skipping")
    sys.exit(0)


if __name__ == "__main__":
    main()
