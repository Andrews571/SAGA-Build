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
| `susfs_resukisu` | [`69b8e73492`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/69b8e734920b8f9ed885ab8d112969719698e242) | 10 | — | — |
| `sukisu` | [`0ca744a888`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/0ca744a88835144c58d8256ebb32c279edabfcde) | 0 | — | — |
| `sukisu_builtin` | [`f9aa2fec23`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/f9aa2fec23c3f4a06a935f69dc04cb85b261e7f3) | 20 | 2026-11-12 | [43241019266](https://github.com/Andrews571/SAGA-Build/actions/runs/43241019266) |
| `susfs_sukisu` | [`0d5b1ceb4c`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/0d5b1ceb4ca4cddbe59d04233f4425a83030aa71) | 22 | — | — |
| `ksunext_susfs_fork` | [`aafde92ae9`](https://github.com/pershoot/KernelSU-Next/commit/aafde92ae9769b42567d8db5feefd838c591633b) | 3 | — | — |
| `susfs_ksunext` | [`478beb806b`](https://gitlab.com/pershoot/susfs4ksu/-/commit/478beb806be11839a73b8ce0c91ccabeb362d60e) | 6 | — | — |
