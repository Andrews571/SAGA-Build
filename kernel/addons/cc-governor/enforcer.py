import sys

# Switches every cpufreq policy to cc_governor a few seconds AFTER boot,
# from a delayed work, instead of making it the compile-time default.
# CPU_FREQ_DEFAULT_GOV_CC=y makes cc_init() run while the cpufreq driver
# creates its policies in early boot -> bootloop before the ROM logo on
# MT6878. Same pattern as the BBRv3 / ADIOS enforcers: 20s first shot
# (after vendor init / mtkpower already wrote its governor), then a few
# retries, then stop for good so a later manual choice is never fought.
#
# Lives inside drivers/cpufreq/cpufreq.c because cpufreq_set_policy() is
# static. Same code path as a write to scaling_governor (store()).
BLOCK = r'''
/* ======================================================
 * SAGA: cc_governor delayed default
 *
 * Switches each policy to "cc_governor" SAGA_CC_ENFORCE_DELAY_SEC after
 * boot (late_initcall + delayed work), then retries a few times and
 * stops. Compile-time default stays schedutil on purpose.
 * ====================================================== */
#ifdef CONFIG_CPU_FREQ_GOV_CC
#include <linux/workqueue.h>

#define SAGA_CC_ENFORCE_DELAY_SEC	20
#define SAGA_CC_ENFORCE_INTERVAL_SEC	20
#define SAGA_CC_ENFORCE_TRIES		3

static struct delayed_work saga_cc_enforce_work;
static int saga_cc_enforce_count;

static void saga_cc_enforce_fn(struct work_struct *work)
{
	struct cpufreq_governor *gov;
	unsigned int cpu;

	gov = get_governor("cc_governor");
	if (!gov) {
		pr_warn("saga: cc_governor not registered, nothing to enforce\n");
		return;
	}

	for_each_online_cpu(cpu) {
		struct cpufreq_policy *policy = cpufreq_cpu_get(cpu);
		int ret;

		if (!policy)
			continue;

		/* one pass per policy: only its first online CPU acts */
		if (cpu != cpumask_first(policy->cpus)) {
			cpufreq_cpu_put(policy);
			continue;
		}

		down_write(&policy->rwsem);
		if (!policy_is_inactive(policy) && has_target() &&
		    policy->governor != gov) {
			ret = cpufreq_set_policy(policy, gov,
						 CPUFREQ_POLICY_UNKNOWN);
			if (ret)
				pr_warn("saga: cc_governor on policy%u failed: %d\n",
					policy->cpu, ret);
			else
				pr_info("saga: policy%u -> cc_governor\n",
					policy->cpu);
		}
		up_write(&policy->rwsem);
		cpufreq_cpu_put(policy);
	}

	module_put(gov->owner);

	if (++saga_cc_enforce_count < SAGA_CC_ENFORCE_TRIES)
		schedule_delayed_work(&saga_cc_enforce_work,
				      SAGA_CC_ENFORCE_INTERVAL_SEC * HZ);
}

static int __init saga_cc_enforce_init(void)
{
	INIT_DELAYED_WORK(&saga_cc_enforce_work, saga_cc_enforce_fn);
	schedule_delayed_work(&saga_cc_enforce_work,
			      SAGA_CC_ENFORCE_DELAY_SEC * HZ);
	return 0;
}
late_initcall(saga_cc_enforce_init);
#endif /* CONFIG_CPU_FREQ_GOV_CC */
'''

MARKER = "saga_cc_enforce_init"
ANCHOR = "core_initcall(cpufreq_core_init);"


def main():
    path = sys.argv[1]
    with open(path, "r") as f:
        content = f.read()
    if MARKER in content:
        print("[info] cc enforcer: already patched — skipping")
        return 0
    if content.count(ANCHOR) != 1:
        print(f"[error] cc enforcer: anchor '{ANCHOR}' not found exactly once in {path}", file=sys.stderr)
        return 1
    content = content.replace(ANCHOR, ANCHOR + "\n" + BLOCK, 1)
    with open(path, "w") as f:
        f.write(content)
    print("[info] cc enforcer: injected ✅")
    return 0


if __name__ == "__main__":
    sys.exit(main())
