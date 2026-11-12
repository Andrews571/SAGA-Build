# Arquitetura do SAGA-Build

Este repo **não tem código-fonte do kernel**: só os scripts e workflows que baixam o fonte, aplicam patches/addons, compilam e publicam.

## Fluxo de uma build (`build.yml`)
1. **prepare-matrix**: monta a matriz de variantes (VANILLA, RESUKISU, SUKISU, KSUNEXT), a lista de addons e valida a versão do kernel e os addons.
2. **Start-Build** (uma por variante): prepara o runner (`setup/runner_prep.sh`), restaura caches (clang, arsenal, ccache, LTO), roda `kernel/checkpoint/scout.sh` e então `build.sh`.
3. **build.sh**: branding → variante (KSU/SuSFS) → core → `run_addons` → `build/make.sh` (compila) → `run_postbuild` → empacota (`run_release`, AnyKernel3). Warm Run para depois do postbuild, sem empacotar.
4. **Checkpoint** (`kernel/checkpoint/engine.sh`): promove ou marca como ruim o commit candidato testado.
5. **Release/Telegram**: `release/telegram/*` publica o post; `build.yml` envia o zip ao SAGA-Releases.

## Modos (`run_mode`)
- **Dry Run**: não compila; valida o fluxo.
- **Warm Run**: compila para aquecer ccache/LTO e testar candidatos (usa `make -k`).
- **Build / Release**: compilação real; falha rápido (sem `-k`).

## Pastas
| Pasta | Conteúdo |
|---|---|
| `.github/workflows/` | `build`, `pin-scout`, `notify`, `lint`, `keep-alive`, `kernel-source`, `mirror-reference` |
| `.github/actions/` | ações compostas (restore/save de caches, setup-arsenal, setup-build-env) |
| `setup/` | caminhos, dependências, ccache, clang, `runner_prep.sh` |
| `build/` | `make.sh` (compilação), `ccache_report.sh` (relatório do ccache) |
| `kernel/addons/<nome>/` | addons (ver `ADDONS.md`) |
| `kernel/checkpoint/` | pin-scout: `scout_precheck.sh`, `scout.sh`, `engine.sh` (ver `PIN-SCOUT.md`) |
| `kernel/android14-6.1-lts/` | patches e `manifest.json` (pins) da versão 6.1 |
| `release/telegram/` | posts do Telegram |

## Segurança dos workflows
- Nunca use `${{ ... }}` dentro de `run:`: passe o valor por `env:` e use `"${VAR}"`.
- `permissions: contents: read` por padrão; eleve só no job que precisa.
- O workflow **Lint** barra erros de sintaxe/expressão; avisos só aparecem no log.

## Convenção de commits
`tipo(escopo): descrição` (`feat`, `fix`, `chore`, `perf`, `docs`, `refactor`, `ci`, `build`, `test`, `revert`). O prefixo define o ícone no Telegram. Use `chore: bump`/`chore: mark` **só** para commits automáticos (chegam sem som).

## Histórico de manutenção
Cada patch de infraestrutura é registrado em [`CHANGELOG-MANUTENCAO.md`](CHANGELOG-MANUTENCAO.md).
