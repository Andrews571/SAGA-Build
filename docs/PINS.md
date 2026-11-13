# Pins verificados

> Gerado automaticamente por `kernel/checkpoint/engine.sh` a cada promoção ou bloqueio de pin. **Não edite à mão.**
> Para regenerar: `bash kernel/checkpoint/pins_doc.sh > docs/PINS.md`.

- **Pin (good):** último commit que compilou e é usado nas builds normais.
- **Ruins:** quantos commits do upstream já falharam e são ignorados.
- **Verificado:** data (UTC) e run da build que promoveu o pin.

## android14-6.1-lts

| Componente | Pin (good) | Ruins | Verificado | Run |
|---|---|---|---|---|
| `resukisu` | [`548d1dda06`](https://github.com/ReSukiSU/ReSukiSU/commit/548d1dda060ca198823d8808804d01f5209ef4a9) | 25 | — | — |
| `susfs_resukisu` | [`342943dbef`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/342943dbef8a1e996354fd94be4a98f4d556f3df) | 10 | 2026-11-13 | [43526477934](https://github.com/Andrews571/SAGA-Build/actions/runs/43526477934) |
| `sukisu` | [`0ca744a888`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/0ca744a88835144c58d8256ebb32c279edabfcde) | 0 | — | — |
| `sukisu_builtin` | [`f9aa2fec23`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/f9aa2fec23c3f4a06a935f69dc04cb85b261e7f3) | 20 | 2026-11-12 | [43241019266](https://github.com/Andrews571/SAGA-Build/actions/runs/43241019266) |
| `susfs_sukisu` | [`342943dbef`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/342943dbef8a1e996354fd94be4a98f4d556f3df) | 22 | 2026-11-13 | [43526477934](https://github.com/Andrews571/SAGA-Build/actions/runs/43526477934) |
| `ksunext_susfs_fork` | [`a7c7f531ca`](https://github.com/pershoot/KernelSU-Next/commit/a7c7f531ca80e9189fd0d8001eb37075de68cc7b) | 3 | 2026-11-13 | [43526477934](https://github.com/Andrews571/SAGA-Build/actions/runs/43526477934) |
| `susfs_ksunext` | [`478beb806b`](https://gitlab.com/pershoot/susfs4ksu/-/commit/478beb806be11839a73b8ce0c91ccabeb362d60e) | 6 | — | — |
