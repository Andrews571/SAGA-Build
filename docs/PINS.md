# Pins verificados

> Gerado automaticamente por `kernel/checkpoint/engine.sh` a cada promoção ou bloqueio de pin. **Não edite à mão.**
> Para regenerar: `bash kernel/checkpoint/pins_doc.sh > docs/PINS.md`.

- **Pin (good):** último commit que compilou e é usado nas builds normais.
- **Ruins:** quantos commits do upstream já falharam e são ignorados.
- **Verificado:** data (UTC) e run da build que promoveu o pin.

## android14-6.1-lts

| Componente | Pin (good) | Ruins | Verificado | Run |
|---|---|---|---|---|
| `resukisu` | [`cac1e79355`](https://github.com/ReSukiSU/ReSukiSU/commit/cac1e79355ef451539f5c5ba9dc2bda1c64069de) | 25 | 2026-11-26 | [45895585547](https://github.com/Andrews571/SAGA-Build/actions/runs/45895585547) |
| `susfs_resukisu` | [`f76b81f2a6`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/f76b81f2a6bf98e4029cc0c823c054edbec29803) | 10 | 2026-11-15 | [43681048288](https://github.com/Andrews571/SAGA-Build/actions/runs/43681048288) |
| `sukisu` | [`0ca744a888`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/0ca744a88835144c58d8256ebb32c279edabfcde) | 0 | — | — |
| `sukisu_builtin` | [`4bec532dd4`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/4bec532dd447e2852aa8932afa768255350c103a) | 20 | 2026-11-15 | [43770130885](https://github.com/Andrews571/SAGA-Build/actions/runs/43770130885) |
| `susfs_sukisu` | [`f76b81f2a6`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/f76b81f2a6bf98e4029cc0c823c054edbec29803) | 22 | 2026-11-15 | [43681048288](https://github.com/Andrews571/SAGA-Build/actions/runs/43681048288) |
| `ksunext_susfs_fork` | [`6238557b3e`](https://github.com/pershoot/KernelSU-Next/commit/6238557b3eb938f3b122b486db77ff149a4fcfa1) | 3 | 2026-11-25 | [45568981751](https://github.com/Andrews571/SAGA-Build/actions/runs/45568981751) |
| `susfs_ksunext` | [`d791ce68f3`](https://gitlab.com/pershoot/susfs4ksu/-/commit/d791ce68f38f067f6489c0c8866e145a903b62e6) | 6 | 2026-11-14 | [43646205412](https://github.com/Andrews571/SAGA-Build/actions/runs/43646205412) |
