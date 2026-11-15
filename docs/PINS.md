# Pins verificados

> Gerado automaticamente por `kernel/checkpoint/engine.sh` a cada promoção ou bloqueio de pin. **Não edite à mão.**
> Para regenerar: `bash kernel/checkpoint/pins_doc.sh > docs/PINS.md`.

- **Pin (good):** último commit que compilou e é usado nas builds normais.
- **Ruins:** quantos commits do upstream já falharam e são ignorados.
- **Verificado:** data (UTC) e run da build que promoveu o pin.

## android14-6.1-lts

| Componente | Pin (good) | Ruins | Verificado | Run |
|---|---|---|---|---|
| `resukisu` | [`5d6d1843c8`](https://github.com/ReSukiSU/ReSukiSU/commit/5d6d1843c8937f5ff2a145dc89a0cf46030ae6f8) | 25 | 2026-11-15 | [43770130885](https://github.com/Andrews571/SAGA-Build/actions/runs/43770130885) |
| `susfs_resukisu` | [`f76b81f2a6`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/f76b81f2a6bf98e4029cc0c823c054edbec29803) | 10 | 2026-11-15 | [43681048288](https://github.com/Andrews571/SAGA-Build/actions/runs/43681048288) |
| `sukisu` | [`0ca744a888`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/0ca744a88835144c58d8256ebb32c279edabfcde) | 0 | — | — |
| `sukisu_builtin` | [`f9aa2fec23`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/f9aa2fec23c3f4a06a935f69dc04cb85b261e7f3) | 20 | 2026-11-12 | [43241019266](https://github.com/Andrews571/SAGA-Build/actions/runs/43241019266) |
| `susfs_sukisu` | [`f76b81f2a6`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/f76b81f2a6bf98e4029cc0c823c054edbec29803) | 22 | 2026-11-15 | [43681048288](https://github.com/Andrews571/SAGA-Build/actions/runs/43681048288) |
| `ksunext_susfs_fork` | [`4776e7cd67`](https://github.com/pershoot/KernelSU-Next/commit/4776e7cd67663a532ca49ec9523cc6e9739d6cf2) | 3 | 2026-11-14 | [43646205412](https://github.com/Andrews571/SAGA-Build/actions/runs/43646205412) |
| `susfs_ksunext` | [`d791ce68f3`](https://gitlab.com/pershoot/susfs4ksu/-/commit/d791ce68f38f067f6489c0c8866e145a903b62e6) | 6 | 2026-11-14 | [43646205412](https://github.com/Andrews571/SAGA-Build/actions/runs/43646205412) |
