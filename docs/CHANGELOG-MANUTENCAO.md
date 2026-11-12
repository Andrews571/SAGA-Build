# Changelog de manutenção — SAGA-Build

Registro de cada mudança de infraestrutura (workflows, scripts, docs): **o quê**, **por quê** e **como**.
Mais recente primeiro. Atualizado a cada patch aplicado. Plano completo: 30 tarefas (T1–T30).

---

## M5 — Runner, `make -k`, docs e badges (T11, T27, T29, T30 parcial)
**Arquivos:** `setup/runner_prep.sh` (novo), `.github/workflows/build.yml`, `build/make.sh`, `docs/ARQUITETURA.md`, `docs/ADDONS.md`, `docs/PIN-SCOUT.md` (novos), `docs/placebo.txt` (removido), `README.md`, `docs/CHANGELOG-MANUTENCAO.md`

| Tarefa | O quê | Por quê | Como |
|---|---|---|---|
| T11 | Swap com retry; limpeza de disco com PID; espera condicional | Uma falha passageira no swap matava o job, e o `rm -rf` em segundo plano podia ainda estar apagando quando o build precisava de espaço | `runner_prep.sh free-disk`: mesmos `mv` e `rm` de antes, gravando o PID em `/tmp/free_disk.pid`. `swap`: até 3 tentativas (`SWAP_ATTEMPTS`) com espera crescente; falha de vez = erro claro. `wait-disk` (passo novo antes de *Setup Build Environment*): só espera se houver menos de `DISK_NEED_GB` (30) livres **e** a limpeza ainda rodar, no máximo 240 s; com espaço de sobra não atrasa nada. Os 30 GB são uma estimativa: ajuste olhando o passo *Disk Usage* |
| T27 | `make -k` só no Warm Run | `-k` continua compilando após um erro; no Build/Release só gasta runner num build já perdido | `make.sh` monta `-k` apenas quando `RUN_MODE` é `WARM RUN`; Build/Release param no primeiro erro |
| T29 | Docs reais no lugar de `docs/placebo.txt` | Era só um arquivo de enfeite | `ARQUITETURA.md` (fluxo, pastas, convenções), `ADDONS.md` (como criar um addon) e `PIN-SCOUT.md` (fluxo e regras de decisão). README ganhou links |
| T30 (parcial) | Badges Lint, Kernel e Download no README | Mostrar estado do lint, o kernel suportado e onde baixar | Lint = status do `lint.yml`; Kernel = badge estático `android14-6.1 GKI`; Download = link para o SAGA-Releases. **Falta o `LICENSE`** (aguarda decisão) |

**Verificação:** `runner_prep.sh` testado com comandos simulados (swap ok na 1ª, ok na 3ª, falha total; espera com espaço sobrando, limpeza já terminada, limpeza ativa com timeout, espaço que aparece); `free-disk` testado só com `mv`/`rm` simulados (nada foi apagado). A lógica do `-k` testada para `Warm Run`, `Build`, `Release` e vazio. Lint local sem erros. Não rodei no GitHub: confira numa run real.

---

## M4 — Pré-check do pin-scout e relatório do ccache (T8, T9)
**Arquivos:** `.github/workflows/pin-scout.yml`, `kernel/checkpoint/scout_precheck.sh` (novo), `.github/workflows/build.yml`, `build/ccache_report.sh` (novo), `build/make.sh`, `docs/CHANGELOG-MANUTENCAO.md`

| Tarefa | O quê | Por quê | Como |
|---|---|---|---|
| T8 | O Pin Scout só dispara o Warm Run quando há algo novo para testar | A cada 6h ele subia 3 variantes (runner pago em minutos) mesmo sem commit novo no upstream | `scout_precheck.sh` compara o topo da branch de cada componente (`git ls-remote`, sem token) com o `manifest.json`, com as **mesmas regras do `scout.sh`** (candidato novo, pin marcado ruim, retry de deadlock). Resultado em `needs_build`; tabela no resumo da run. **Fail-open:** se o pré-check falhar, o build é disparado. Nova entrada manual `force` ignora o pré-check. Menu `kernel_version` do pin-scout só com `6.1` (mesma regra do T6) |
| T9 | Relatório de hit rate do ccache por variante | O limite de 900 MB era um palpite; sem medir não dá para saber se o cache é pequeno | `make.sh` zera os contadores (`--zero-stats`) antes de compilar, para medir só **este** build. O passo "Ccache Stats" roda `ccache_report.sh`: taxa de acertos, misses, `cleanups` e tamanho, e dá um veredito: ✅ ≥ 90%; ⚠️ abaixo de 90% **e** cache cheio/descartando arquivos (subir `CCACHE_MAXSIZE`); ℹ️ abaixo de 90% com cache folgado (cache frio ou muito código novo). Tabela no resumo da run e `::warning` no caso ⚠️ |

**Manutenção:** a lista `COMPONENTS` do `scout_precheck.sh` espelha o `scout.sh`; se um componente for adicionado ou trocado lá, atualize aqui também.

**Verificação:** `scout_precheck.sh` testado com upstream simulado (tudo igual→não dispara; candidato novo→dispara; último commit ruim→não dispara; falha de lookup→não dispara; `force`→dispara; sem manifest→dispara) e contra o GitHub real (ReSukiSU e KSU-Next iguais ao pin; SukiSU `builtin` já marcado ruim). `ccache_report.sh` testado com 6 saídas simuladas (`--print-stats`, texto 4.4+, texto antigo, taxa alta, cache cheio, zero chamadas). Não havia `ccache` real no ambiente de teste: confira a primeira run real.

---

## M3 — Versões de kernel e lint (T6, T7)
**Arquivos:** `.github/workflows/build.yml`, `.github/workflows/lint.yml` (novo), `docs/CHANGELOG-MANUTENCAO.md`

| Tarefa | O quê | Por quê | Como |
|---|---|---|---|
| T6 | Menu `kernel_version` só oferece `6.1`; novo passo **Validate Kernel Version** no `prepare-matrix` | O menu listava 5.10/5.15/6.6/6.12, que não existem no repo: o build gastava minutos e morria com "not yet supported" | Remove as opções inexistentes. O passo procura `kernel/android*-<versão>-lts` e falha em segundos com `::error` listando as versões suportadas. Kernel novo = criar a pasta **e** acrescentar a opção no menu |
| T7 | Workflow **🔎 Lint** (push/PR em `.github/**`, `*.sh`, `*.py`, e manual) | Nada validava os workflows e scripts antes de rodarem em produção | **Bloqueiam:** `actionlint -shellcheck=` (estrutura/expressões), `bash -n`, `shellcheck -S error`, `py_compile`. **Não bloqueiam:** `shellcheck -S warning` e `actionlint` com shellcheck embutido (aparecem no log, `continue-on-error`). Ferramentas fixadas: actionlint-py 1.7.12.25, shellcheck-py 0.11.0.1 |

**Verificação:** os 4 passos bloqueantes passam no repo atual (0 erros). Teste negativo: um `length()` inválido num workflow gera a anotação de erro e falha o passo; `bash -n` falha em script quebrado. Commits de pin (só `manifest.json`) não disparam o lint.

---

## M2 — Notificação de push do Telegram (T3, T13, T14, T15)
**Arquivos:** `.github/workflows/notify.yml`, `release/telegram/push_notify.sh` (novo), `docs/CHANGELOG-MANUTENCAO.md` (novo)

| Tarefa | O quê | Por quê | Como |
|---|---|---|---|
| T3 | Commits `chore: bump …` / `chore: mark …` chegam **sem som** | O bot comita pins várias vezes ao dia e cada um notificava o celular | `disable_notification=true` quando o título casa `^chore(escopo)?: (bump\|mark) ` |
| T13 | Corpo do commit truncado | Telegram rejeita mensagens > 4096 caracteres e o aviso se perdia | Corpo cortado em 2500 chars antes do escape; se ainda passar de 4096, reduz pela metade até caber; marca `… (truncated, see commit)` |
| T14 | Post mostra nº de commits do push e `N files +x/−y` | Só aparecia o último commit, sem noção do tamanho da mudança | `git diff --shortstat BEFORE COMMIT` (fallback `git show --shortstat` em branch nova/force-push); nº de commits via `git rev-list --count BEFORE..COMMIT`; checkout com `fetch-depth: 0` |
| T15 | Ícone conforme prefixo Conventional Commit | Ícone era sempre 📌 | `feat`✨ `fix`🐛 `chore`🧹 `perf`⚡ `docs`📝 `refactor`♻️ `ci/build`⚙️ `test`🧪 `revert`⏪; sem prefixo 📌 |

**Detalhes:** a lógica saiu do YAML para `push_notify.sh`, que roda em modo teste com `TG_DRY_RUN=1` (imprime em vez de enviar). Passa em `shellcheck`.

---

## M1 — Segurança dos workflows (T1, T2) — commit `a2a7f8a`
**Arquivos:** `build.yml`, `kernel-source.yml`, `mirror-reference.yml`, 7 ações em `.github/actions/`, `keep-alive.yml`, `notify.yml`, `pin-scout.yml`

| Tarefa | O quê | Por quê | Como |
|---|---|---|---|
| T1 | Todo `${{ … }}` dentro de `run:` virou variável de ambiente | A expressão era colada no script antes da execução; um `input` de texto livre poderia injetar comandos | Valor movido para `env:` (`IN_*` inputs, `MX_*` matrix, `ST_*` outputs de steps, `SEC_*` secrets) e usado como `"${VAR}"`. Booleanos: `[ "${IN_X}" = "true" ]` |
| T2 | `permissions: contents: read` em todos os workflows | O `GITHUB_TOKEN` tinha permissões padrão amplas | Bloco `permissions` no topo; `keep-alive` usa `{}` no topo e `actions: read` só no job `list-caches`. Pushes/releases já usavam PAT |

**Verificação:** `git apply --check` em clone limpo, YAML válido, `actionlint` sem novos avisos (44 antes e depois, todos infos antigos de shellcheck), Dry Run do `build.yml` OK.
