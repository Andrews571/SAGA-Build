# eevdf-bore — EEVDF + BORE 7.0 para android14-6.1

**Status: compila (objetos do escalonador), NÃO testado em boot.** Opt-in:
workflow → `cpu_scheduler = EEVDF_BORE`. O padrão continua `BORE_CFS` (addon `bore`).

## O que muda no kernel
| Patch | Conteúdo |
|---|---|
| 0001 | infra EEVDF (`avg_vruntime`), remove buddies `last/skip` |
| 0002 | EEVDF nível 6.6: `pick_eevdf`, rbtree aumentada (`min_deadline`), `place_entity` + PLACE_LAG, deadline/slice, yield, preempção no wakeup |
| 0003 | `protect_slice`, `PREEMPT_SHORT`, `PLACE_REL_DEADLINE` |
| 0004 | BORE 7.0.0 + `sched_bore_topapp_discount` / `_smooth_boost` |

Fora do escopo: delayed dequeue, custom slice, árvore ordenada por deadline do 6.12.

## KMI
Estado novo usa o padding `ANDROID_KABI_RESERVE` (sched_entity 1-4, task_struct 4-8) e
troca de lugar `last/skip` ↔ `avg_vruntime/avg_load` no `cfs_rq`. Conferido com
`-fdump-record-layouts`: tamanhos e offsets de `sched_entity`(320), `cfs_rq`(384),
`rq`(3840), `task_struct`(4800) iguais à base.

## Conflitos
`bore` e `bore-warp` (o build aborta). O workflow tira o `bore-warp` do perfil `CC_Addons`
quando `EEVDF_BORE` é escolhido. Testado em dry-run junto com: util-avg-fix, cc-governor,
clutch-signals, reflex, kcompressd, le9uo.

## Hooks vendor
`android_rvh_check_preempt_tick` deixa de disparar (função removida pelo EEVDF).
Os demais (enqueue/dequeue_entity, place_entity, pick_next_entity, entity_tick,
check_preempt_wakeup, reweight_entity, ...) continuam.

## Teste no aparelho (antes de confiar)
1. Mantenha o zip anterior para flash de volta.
2. `adb shell dmesg | grep -i "BORE CPU"` → "BORE CPU Scheduler modification 7.0.0".
3. `adb shell su -c 'ls /proc/sys/kernel | grep sched_'` e `cat /sys/kernel/debug/sched/base_slice_ns`.
4. `sched_bore=0` desliga o BORE em runtime (fica EEVDF puro) — útil para A/B.
5. Estresse: `hackbench`, rolagem/abertura de apps, jogo; olhe `dmesg` por "EEVDF scheduling fail" e WARNs de sched.
