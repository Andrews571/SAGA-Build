import sys

# Re-asserts bbr3 as net.ipv4.tcp_congestion_control a handful of times
# during early boot so a vendor init script writing over it doesn't stick
# (confirmed root cause on MediaTek devices: /vendor/etc/init/*.rc scripts
# running at `on early-init`, e.g. `write .../tcp_congestion_control bic`).
# # Stops after SAGA_BBR3_ENFORCE_TRIES — this only needs to win the
# boot-time race, not fight the user's own later choice (e.g. manually
# switching algorithm via a kernel manager app).
#
# Lives inside net/ipv4/tcp_cong.c rather than a new file because
# tcp_set_default_congestion_control() isn't EXPORT_SYMBOL'd — it's only
# callable from within the same translation unit.
ENFORCER_BLOCK = '''
/* ======================================================
 * SAGA: BBRv3 default-congestion enforcer
 *
 * Re-asserts bbr3 as net.ipv4.tcp_congestion_control a handful of times
 * during early boot so a vendor init script writing over it doesn't
 * stick. Stops after SAGA_BBR3_ENFORCE_TRIES — this only needs to
 * win the boot-time race, not fight the user's own later choice (e.g.
 * manually switching algorithm via a kernel manager app).
 * ====================================================== */
#ifdef CONFIG_TCP_CONG_BBR3
#include <linux/workqueue.h>

#define SAGA_BBR3_ENFORCE_TRIES 5

static struct delayed_work saga_bbr3_enforce_work;
static int saga_bbr3_enforce_count;

static void saga_bbr3_enforce_fn(struct work_struct *work)
{
\ttcp_set_default_congestion_control(&init_net, "bbr3");
\tif (++saga_bbr3_enforce_count < SAGA_BBR3_ENFORCE_TRIES)
\t\tschedule_delayed_work(&saga_bbr3_enforce_work, 20 * HZ);
}

static int __init saga_bbr3_enforce_init(void)
{
\tINIT_DELAYED_WORK(&saga_bbr3_enforce_work, saga_bbr3_enforce_fn);
\t/* First shot after 20s — late enough that it lands after typical
\t * vendor "on boot"/"on property:sys.boot_completed=1" triggers.
\t * Repeats every 20s up to SAGA_BBR3_ENFORCE_TRIES, covering the
\t * first ~100s of boot, then stops for good — so it never fights a
\t * choice the user makes later on. */
\tschedule_delayed_work(&saga_bbr3_enforce_work, 20 * HZ);
\treturn 0;
}
late_initcall(saga_bbr3_enforce_init);
#endif /* CONFIG_TCP_CONG_BBR3 */
'''

# Old (pre-rename) marker: a kernel source tree restored from
# USE_KERNEL_CACHE (see download/make.sh) may already have this injected
# under the old luminaire_* symbol names from a build that ran before this
# rename. Checking only the new marker would miss that, and — since the
# anchor line below is left in place by the injection (it's matched with
# a trailing replace, not consumed) — re-running against that same cached
# tree would inject a *second*, differently-named copy instead of
# correctly detecting "already patched" and skipping.
MARKER = "saga_bbr3_enforce_init"
LEGACY_MARKER = "luminaire_bbr3_enforce_init"


def main():
    path = sys.argv[1]

    with open(path, "r") as f:
        content = f.read()

    if MARKER in content or LEGACY_MARKER in content:
        print("[info] bbrv3 enforcer: already patched — skipping")
        sys.exit(0)

    anchor = "late_initcall(tcp_congestion_default);"
    if anchor not in content:
        print(f"[error] bbrv3 enforcer: anchor '{anchor}' not found in {path} "
              f"— upstream may have refactored tcp_cong.c!", file=sys.stderr)
        sys.exit(1)

    content = content.replace(anchor, anchor + "\n" + ENFORCER_BLOCK, 1)

    with open(path, "w") as f:
        f.write(content)

    print("[info] bbrv3 enforcer: injected ✅")
    sys.exit(0)


if __name__ == "__main__":
    main()
