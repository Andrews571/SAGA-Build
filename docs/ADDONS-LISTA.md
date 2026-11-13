# Addons

> Gerado de `kernel/addons/*/addon.meta` com `bash kernel/checkpoint/addon_watch.sh doc > docs/ADDONS-LISTA.md`. **Não edite à mão.**

- **Modo:** `local` (código do SAGA), `vendored-patch` (cópia de patch do upstream), `fetch-latest` (baixa o upstream a cada build, sem fixar versão), `git-clone` (clona o upstream a cada build).
- **Vigiado:** o Pin Scout avisa por issue quando o upstream muda (`branch` = topo da branch; `path` = último commit que toca o caminho). `—` = não vigiado.
- **Licença:** do upstream/código de origem; `?` = não confirmada (sem arquivo LICENSE ou SPDX).

| Addon | O que faz | Modo | Origem | Licença | Vigiado |
|---|---|---|---|---|---|
| `adios-clutch` | Variante experimental do ADIOS; exclusiva com o addon adios | local | SAGA | GPL-2.0 | — |
| `adios` | ADIOS: escalonador de I/O adaptativo por deadline (firelzrd) | vendored-patch | [firelzrd/adios](https://github.com/firelzrd/adios) | GPL-2.0 | branch `HEAD` |
| `bbg` | BBG: LSM Baseband Guard | fetch-latest | [vc-teahouse/Baseband-guard](https://github.com/vc-teahouse/Baseband-guard) | GPL-2.0 | caminho `setup.sh` |
| `bbrv3` | BBRv3: controle de congestionamento TCP (backport de fatalcoder524) | fetch-latest | [WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches) | ? | caminho `common/bbrv3` |
| `bore-warp` | BORE-WARP: extensão do BORE com preempção limitada (SAGA) | local | SAGA | ? | — |
| `bore` | BORE: escalonador de CPU orientado a bursts (firelzrd) | vendored-patch | [firelzrd/bore-scheduler](https://github.com/firelzrd/bore-scheduler) | GPL-2.0 | branch `HEAD` |
| `cc-governor` | CC Governor (Cerebral Clutch): governor conservador (SAGA) | local | SAGA | GPL-2.0 | — |
| `clutch-signals` | Ponte neutra de sinais entre ADIOS (I/O) e CC governor (CPU) (SAGA) | local | SAGA | GPL-2.0 | — |
| `droidspaces` | Droidspaces: suporte a runtime de containers LXC | local | [ravindu644/Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) | GPL-3.0 | — |
| `kasumi` | Kasumi: LKM de manipulação/ocultação de caminhos | git-clone | [Anatdx/Kasumi](https://github.com/Anatdx/Kasumi) | Apache-2.0 | branch `HEAD` |
| `kcompressd` | Kcompressd: compressão de memória em thread dedicada | vendored-patch | [firelzrd/kcompressd-unofficial](https://github.com/firelzrd/kcompressd-unofficial) | GPL-2.0 | branch `HEAD` |
| `le9uo` | le9uo: proteção do working set de memória | vendored-patch | [firelzrd/le9uo](https://github.com/firelzrd/le9uo) | GPL-2.0 | branch `HEAD` |
| `lz4kd` | LZ4KD: backends lz4k/lz4kd para zram | fetch-latest | [SukiSU-Ultra/SukiSU_patch](https://github.com/SukiSU-Ultra/SukiSU_patch) | ? | caminho `other/zram` |
| `lz4zstd` | LZ4 1.10.0 + ZSTD 1.5.7 para zram | fetch-latest | [mrcxlinux/kernel_patches](https://github.com/mrcxlinux/kernel_patches) | ? | caminho `zram` |
| `mglru` | MGLRU: força a ativação adaptativa em mm/vmscan.c | local | SAGA | ? | — |
| `nomount` | NoMount: framework de injeção de caminhos VFS (beta) | git-clone | [maxsteeel/nomount](https://github.com/maxsteeel/nomount) | GPL-3.0 | branch `HEAD` |
| `ntsync` | NTSync: primitivas de sincronização NT no kernel (Wine/Winlator) | fetch-latest | [WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches) | ? | caminho `common/ntsync` |
| `pm-wakelock-blocker` | Bloqueador de wakelock nomeado (SAGA) | local | SAGA | ? | — |
| `reflex` | REFLEX: governor de cpufreq (reescrita do SAGA) | local | SAGA | GPL-2.0 | — |
| `rekernel` | Re:Kernel: servidor Netlink para eventos de Binder/sinais | vendored-patch | [Sakion-Team/Re-Kernel](https://github.com/Sakion-Team/Re-Kernel) | GPL-2.0 | branch `HEAD` |
| `schedutil` | Força o governor schedutil como padrão | local | SAGA | ? | — |
| `unicode-fix` | Correção do bypass de normalização Unicode (fs/unicode) | fetch-latest | [WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches) | ? | caminho `common/unicode_bypass_fix_6.1+.patch` |
| `util-avg-fix` | Correção do cálculo inicial de util_avg em sched/fair | local | SAGA | ? | — |
| `zeromount` | ZeroMount: redirecionamento de caminhos VFS | fetch-latest | [Enginex0/Super-Builders](https://github.com/Enginex0/Super-Builders) | ? | caminho `android14-6.1/ReSukiSU/patches/60_zeromount-android14-6.1.patch` |
| `zram-ir` | ZRAM-IR: recompressão imediata no zram | vendored-patch | [firelzrd/zram-ir](https://github.com/firelzrd/zram-ir) | GPL-2.0 | branch `HEAD` |
