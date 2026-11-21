# Pins verificados

> Gerado automaticamente por `kernel/checkpoint/engine.sh` a cada promoção ou bloqueio de pin. **Não edite à mão.**
> Para regenerar: `bash kernel/checkpoint/pins_doc.sh > docs/PINS.md`.

- **Pin (good):** último commit que compilou e é usado nas builds normais.
- **Ruins:** quantos commits do upstream já falharam e são ignorados.
- **Verificado:** data (UTC) e run da build que promoveu o pin.

## android14-6.1-lts

| Componente | Pin (good) | Ruins | Verificado | Run |
|---|---|---|---|---|
| `resukisu` | [`7b65bde071`](https://github.com/ReSukiSU/ReSukiSU/commit/7b65bde0710b5e7c6f755545cb15a4abd417f3a8) | 25 | 2026-11-16 | [43893230813](https://github.com/Andrews571/SAGA-Build/actions/runs/43893230813) |
| `susfs_resukisu` | [`f76b81f2a6`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/f76b81f2a6bf98e4029cc0c823c054edbec29803) | 10 | 2026-11-15 | [43681048288](https://github.com/Andrews571/SAGA-Build/actions/runs/43681048288) |
| `sukisu` | [`0ca744a888`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/0ca744a88835144c58d8256ebb32c279edabfcde) | 0 | — | — |
| `sukisu_builtin` | [`4bec532dd4`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/4bec532dd447e2852aa8932afa768255350c103a) | 20 | 2026-11-15 | [43770130885](https://github.com/Andrews571/SAGA-Build/actions/runs/43770130885) |
| `susfs_sukisu` | [`f76b81f2a6`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/f76b81f2a6bf98e4029cc0c823c054edbec29803) | 22 | 2026-11-15 | [43681048288](https://github.com/Andrews571/SAGA-Build/actions/runs/43681048288) |
| `ksunext_susfs_fork` | [`9940bcc841`](https://github.com/pershoot/KernelSU-Next/commit/9940bcc8414555c2f9a282aa100c916104619d8e) | 3 | 2026-11-21 | [44937627531](https://github.com/Andrews571/SAGA-Build/actions/runs/44937627531) |
| `susfs_ksunext` | [`d791ce68f3`](https://gitlab.com/pershoot/susfs4ksu/-/commit/d791ce68f38f067f6489c0c8866e145a903b62e6) | 6 | 2026-11-14 | [43646205412](https://github.com/Andrews571/SAGA-Build/actions/runs/43646205412) |
