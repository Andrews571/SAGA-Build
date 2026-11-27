#!/usr/bin/env python3
"""mm-backports (SAGA): 3 pequenos backports do mainline para android14-6.1.
  psi-states   : 0ec208ce98 (6.11) sched/psi: Optimise psi_group_change a bit
  psi-irq      : 0c2924079f (6.7)  sched/psi: bail out early from irq time accounting
  rmap-exiting : c495b97624 (6.11) mm: shrink skip folio mapped by an exiting process
Uso: patch.py <KERNEL_SRC>. Idempotente; forma diferente => avisa e pula (nunca quebra o build)."""
import sys, os

SRC = sys.argv[1]
MARK = "SAGA: mm-backports"

def rd(p):
    with open(os.path.join(SRC, p)) as f: return f.read()
def wr(p, s):
    with open(os.path.join(SRC, p), "w") as f: f.write(s)

def apply(name, path, edits):
    try: s = rd(path)
    except OSError: print(f"warn: {path} missing, skip {name}"); return
    if MARK + " " + name in s: print(f"ok: {name} already applied"); return
    for old, new in edits:
        if s.count(old) != 1:
            print(f"warn: {name}: shape differs in {path}, skipped"); return
        s = s.replace(old, new)
    # marcador no primeiro bloco editado
    first = edits[0][1]
    s = s.replace(first, first + "", 1)
    s += f"\n/* {MARK} {name} */\n"
    wr(path, s); print(f"ok: {name} applied")

OLD_TS = rd("kernel/sched/psi.c") if os.path.exists(os.path.join(SRC, "kernel/sched/psi.c")) else ""
i0 = OLD_TS.find("static bool test_state(")
i1 = OLD_TS.find("static void get_recent_times(") if i0 >= 0 else -1
old_fn = OLD_TS[i0:i1].rstrip("\n") if i0 >= 0 and i1 > i0 else "@@none@@"

NEW_FN = """static u32 test_states(unsigned int *tasks, u32 state_mask)
{
	const bool oncpu = state_mask & PSI_ONCPU;

	if (tasks[NR_IOWAIT]) {
		state_mask |= BIT(PSI_IO_SOME);
		if (!tasks[NR_RUNNING])
			state_mask |= BIT(PSI_IO_FULL);
	}

	if (tasks[NR_MEMSTALL]) {
		state_mask |= BIT(PSI_MEM_SOME);
		if (tasks[NR_RUNNING] == tasks[NR_MEMSTALL_RUNNING])
			state_mask |= BIT(PSI_MEM_FULL);
	}

	if (tasks[NR_RUNNING] > oncpu)
		state_mask |= BIT(PSI_CPU_SOME);

	if (tasks[NR_RUNNING] && !oncpu)
		state_mask |= BIT(PSI_CPU_FULL);

	if (tasks[NR_IOWAIT] || tasks[NR_MEMSTALL] || tasks[NR_RUNNING])
		state_mask |= BIT(PSI_NONIDLE);

	return state_mask;
}"""

apply("psi-states", "kernel/sched/psi.c", [
    (old_fn, NEW_FN),
    ("""	for (s = 0; s < NR_PSI_STATES; s++) {
		if (test_state(groupc->tasks, s, state_mask & PSI_ONCPU))
			state_mask |= (1 << s);
	}
""", "	state_mask = test_states(groupc->tasks, state_mask);\n"),
    ("	unsigned int t, m;\n	enum psi_states s;\n	u32 state_mask;\n", "	unsigned int t, m;\n	u32 state_mask;\n"),
    ("stop test_state() loop", "stop test_states() loop"),
    ("from test_state() loop on tasks[]", "from test_states() loop on tasks[]"),
])

apply("psi-irq", "kernel/sched/psi.c", [
    ("""	u64 irq;

	if (!curr->pid)
		return;

	lockdep_assert_rq_held(rq);""", """	u64 irq;

	if (static_branch_likely(&psi_disabled))
		return;

	if (!curr->pid)
		return;

	lockdep_assert_rq_held(rq);"""),
])

apply("rmap-exiting", "mm/rmap.c", [
    ("#include <linux/mm_inline.h>\n", "#include <linux/mm_inline.h>\n#include <linux/oom.h>\n"),
    ("""			pra->vm_flags |= VM_LOCKED;
			return false; /* To break the loop */
		}

		if (pvmw.pte) {
			trace_android_vh_look_around""", """			pra->vm_flags |= VM_LOCKED;
			return false; /* To break the loop */
		}

		/*
		 * Skip the non-shared swapbacked folio mapped solely by the
		 * exiting or OOM-reaped process (avoids a redundant swap-out
		 * followed by an immediate unmap). -1 => FOLIOREF_KEEP.
		 */
		if ((!atomic_read(&vma->vm_mm->mm_users) ||
		     check_stable_address_space(vma->vm_mm)) &&
		    folio_test_anon(folio) && folio_test_swapbacked(folio) &&
		    folio_estimated_sharers(folio) <= 1) {
			pra->referenced = -1;
			page_vma_mapped_walk_done(&pvmw);
			return false;
		}

		if (pvmw.pte) {
			trace_android_vh_look_around"""),
])
