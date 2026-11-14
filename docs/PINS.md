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
| `susfs_resukisu` | [`e6dc76f567`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/e6dc76f5671835e71b733e8b2929a7b2406cb458) | 10 | 2026-11-14 | [43598329734](https://github.com/Andrews571/SAGA-Build/actions/runs/43598329734) |
| `sukisu` | [`0ca744a888`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/0ca744a88835144c58d8256ebb32c279edabfcde) | 0 | — | — |
| `sukisu_builtin` | [`f9aa2fec23`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/f9aa2fec23c3f4a06a935f69dc04cb85b261e7f3) | 20 | 2026-11-12 | [43241019266](https://github.com/Andrews571/SAGA-Build/actions/runs/43241019266) |
| `susfs_sukisu` | [`e6dc76f567`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/e6dc76f5671835e71b733e8b2929a7b2406cb458) | 22 | 2026-11-14 | [43598329734](https://github.com/Andrews571/SAGA-Build/actions/runs/43598329734) |
| `ksunext_susfs_fork` | [`72ca104046`](https://github.com/pershoot/KernelSU-Next/commit/72ca104046a17b5cdaecfb9d12f8405241f2a35b) | 3 | 2026-11-14 | [43598329734](https://github.com/Andrews571/SAGA-Build/actions/runs/43598329734) |
| `susfs_ksunext` | [`2b2118a2b9`](https://gitlab.com/pershoot/susfs4ksu/-/commit/2b2118a2b90aaac2ac641b1a12070efbcf5206f0) | 6 | 2026-11-14 | [43598329734](https://github.com/Andrews571/SAGA-Build/actions/runs/43598329734) |
