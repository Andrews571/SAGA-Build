# Changelog de manutenção — SAGA-Build

Registro de cada mudança de infraestrutura (workflows, scripts, docs): **o quê**, **por quê** e **como**.
Mais recente primeiro. Atualizado a cada patch aplicado. Plano completo: 30 tarefas (T1–T30).

---

## M8 — Post unificado do Telegram e identidade CC
**Arquivos:** `release/telegram/unified_caption.py` (novo, do outro chat), `release/telegram/channel_post.sh`, `release/telegram/caption.py`, `release/telegram/telegram.sh`, `release/anykernel.sh`, `release/github/github_release.sh`, `.github/workflows/build.yml`, `docs/POST-TELEGRAM.md` (novo), `docs/CHANGELOG-MANUTENCAO.md`

| O quê | Por quê | Como |
|---|---|---|
| Um post só para canal e SAGA CHAT | Havia dois formatos (rich message com tabelas no canal e foto+legenda no chat) e nenhum era refinado | `channel_post.sh` gera o texto com `unified_caption.py` (título, Download por variante, bloco **Features** expansível com versão dos addons, changelog, links, bug report, hashtags) e envia o mesmo post ao canal e ao chat: `sendMessage` com prévia do banner acima do texto; se falhar, `sendPhoto` com a versão curta (≤1024). Se qualquer destino falhar, o job falha. O estilo com tabelas (rich message) ficou **comentado** no mesmo arquivo, com instruções para reativar |
| Identidade dos builds CC | Distinguir os dois perfis de addons | `ADDON_PROFILE=CC_Addons` → zip `SAGA_CC-<ver>-<variante>-R<n>.zip`, título `SAGA_CC`, variantes `<Variante> - CC` e `#CCKernel` no post; o post por build (tópico de CI) também mostra `SAGA_CC`. `ADDON_PROFILE` passou a existir no env do `Start-Build` e do `Notify Channel` |
| Publicação no SAGA-Releases aceita `SAGA_CC-` | O glob e o regex só reconheciam `SAGA-*.zip`, então um zip CC seria ignorado e a publicação ficaria vazia; o download de artefatos (`pattern`) também | Glob `SAGA*.zip`, regex `^(SAGA(_CC)?)-...`, `pattern: SAGA*.zip`. Os **assets** continuam `SAGA-...` por padrão (contrato do app de OTA); `SAGA_ASSET_KEEP_PREFIX=true` publica `SAGA_CC-...` |

**Verificação:** `unified_caption.py` gerado para os dois perfis com versões de BORE/ADIOS/addons. `channel_post.sh` rodado ponta a ponta com um `curl` simulado: sucesso (canal e chat), falha do `sendMessage` com queda para `sendPhoto`, falha total com erro. Regex dos zips testada com `SAGA-`, `SAGA_CC-` e nomes inválidos. Lint local sem erros. **Não testado contra o Telegram de verdade**: a prévia do banner e o bloco expansível dependem do cliente do Telegram.

---

## M7 — Vigilância de addons, nível de disco `none` e README (T20, T28)
**Arquivos:** `kernel/addons/*/addon.meta` (25 novos), `kernel/checkpoint/addon_watch.sh` (novo), `.github/workflows/pin-scout.yml`, `.github/workflows/lint.yml`, `.github/workflows/build.yml`, `setup/runner_prep.sh`, `README.md`, `docs/ADDONS.md`, `docs/ADDONS-LISTA.md` (novo, gerado), `docs/PIN-SCOUT.md`, `docs/CHANGELOG-MANUTENCAO.md`

| Tarefa | O quê | Por quê | Como |
|---|---|---|---|
| T20 | `addon.meta` em cada addon + vigilância do upstream | Não dava para saber de onde vinha cada addon, qual licença, nem quando o upstream mudava (vários baixam a `main` a cada build, sem fixar versão) | 25 `addon.meta` com `mode`, `upstream`, `license`, `track`, `seen`. Preenchidos só com evidência: URL e forma de download lidas dos scripts, licença lida do arquivo LICENSE do upstream (ou SPDX do patch); sem prova fica `?`. `addon_watch.sh check` compara o upstream com `seen` (topo da branch, ou último commit que toca o caminho baixado) e mantém **uma** issue `📦 Addon upstream updates` (rótulo `addon-upstream`), que fecha sozinha quando tudo está em dia. Roda a cada 6 h como job **Watch addon upstreams** no `pin-scout.yml` (`continue-on-error`, só informa). `accept` marca como revisado; `validate` roda no **Lint** (barra addon sem `addon.meta` ou inválido); `doc` gera `docs/ADDONS-LISTA.md`. Cobre BORE, ADIOS, BBG, ntsync, BBRv3, kasumi, nomount, rekernel, le9uo, kcompressd, zram-ir, lz4kd, lz4zstd, unicode-fix e zeromount |
| FREE_DISK `none` | Nível de limpeza `none` e variáveis de repositório | Os logs mostraram 86 GB livres antes de qualquer limpeza (disco de 145 GB) | `FREE_DISK_LEVEL=none` não apaga nada e escala para `full` se sobrar menos de `DISK_NEED_GB`. `FREE_DISK_LEVEL` e `DISK_NEED_GB` agora vêm de `vars.*` (Settings → Variables), sem commit; padrões `lean` e `30`. Novo passo **Disk Report** mostra o espaço livre no fim do job, perto do pico, para decidir com dados |
| T28 | README completo | Faltavam variantes, kernels, addons e como disparar uma build | Seções Download (canais stable/experimental), Variantes e kernels suportados, Addons (link para a lista), Como rodar uma build (entradas e modos) |

**Observações:**
- `seen` é o commit do upstream **na data da revisão** (2026-11-12), não o commit de onde veio um patch `vendored-patch`; na primeira revisão de cada addon isso é só um ponto de partida.
- Repos de origem sem arquivo LICENSE (WildKernels/kernel_patches, SukiSU_patch, mrcxlinux/kernel_patches, Super-Builders) ficam com licença `?`.
- Não foi possível incluir captura do post do Telegram no README (sem acesso ao canal) e o link `t.me/c/...` do badge continua só para membros.

**Verificação:** `addon_watch.sh` rodado contra o GitHub real (15 addons vigiados, todos "em dia", ~4 s); mudança simulada em branch e em caminho (clone parcial); criar, editar e fechar a issue com `gh` simulado; `accept`; `validate` com os três erros típicos; `doc`. `runner_prep.sh` com `none` (sem espaço sobrando e com espaço) e `report`. Lint local sem erros. Não rodei no GitHub.

---

## M6 — Pins, issues de patch, paralelismo, disco, licença e badges (T19, T22, T23, T26, T30)
**Arquivos:** `kernel/checkpoint/pins_doc.sh`, `kernel/checkpoint/patch_issue.sh` (novos), `kernel/checkpoint/engine.sh`, `functions.sh`, `build/make.sh`, `setup/runner_prep.sh`, `docs/PINS.md` (novo, gerado), `docs/PIN-SCOUT.md`, `LICENSE` (novo), `README.md`, `docs/CHANGELOG-MANUTENCAO.md`

| Tarefa | O quê | Por quê | Como |
|---|---|---|---|
| T19 | `docs/PINS.md` com a tabela de pins | Ninguém via o estado do mecanismo de pins | `pins_doc.sh` lê todos os `manifest.json` e gera: componente, pin com link para o commit, nº de commits ruins, data e run. O `engine.sh` regenera o arquivo **no mesmo commit** de cada bump/mark e, ao promover, grava `verified: {run, at}` no manifest (campo extra, ignorado por `scout.sh` e pelo pré-check). Pins antigos mostram "—" até a próxima promoção |
| T22 | Issue automática quando um patch deixa de aplicar | Cada falha exigia caçar o trecho no log | `error()` (`functions.sh`) grava a última mensagem. `patch_issue.sh`, chamado pelo `engine.sh` após build com falha, reconhece falha de patch (mensagem "apply failed"/"patch file not found" ou arquivos `.rej`) e abre ou comenta a issue `🧩 Patch failed to apply: <etapa> (<kernel>)` com etapa, variante, link da run e os trechos rejeitados (limitados). Rótulo `patch-broken`. **Não fecha sozinha** (o mesmo patch pode passar numa variante e falhar em outra) |
| T23 | `make -j` = `nproc + 2` | Manter a CPU ocupada enquanto jobs esperam o disco | `MAKE_JOBS` (valor absoluto) ou `MAKE_JOBS_EXTRA` (padrão 2; `0` volta ao antigo). ThinLTO continua `nproc/2` por padrão, agora ajustável com `THINLTO_JOBS`. O log mostra "Parallelism: make -jN…" |
| T26 | Limpeza de disco enxuta com escalonamento | Apagar tudo custa I/O que disputa com a restauração de caches | `FREE_DISK_LEVEL=lean` (padrão) apaga só dotnet e android. Se, ao fim da limpeza, houver menos de `DISK_NEED_GB` (30) livres, o `wait-disk` escala sozinho para a limpeza completa (ghc, jvm, swift, powershell, docker, snapd, linuxbrew) e emite `::notice`. `FREE_DISK_LEVEL=full` restaura o comportamento anterior |
| T30 | `LICENSE` GLWTS e badges dinâmicos | Licença do projeto de origem; mostrar o release atual sem editar o README | `LICENSE` copiado do repo original (GLWTS). Badges kernel/stable/experimental leem `saga-release.json` dos ponteiros `ptr-stable` e `ptr-experimental` do SAGA-Releases (`$.kernel.version` e `$.kernel.run`) via shields.io; badge de licença |

**Verificação:** `engine.sh` testado de ponta a ponta contra um repositório git local (promoção cria o commit com `manifest.json` + `PINS.md` + `verified`); `patch_issue.sh` com `gh` simulado (falha de patch com e sem `.rej`, erro não relacionado, issue já aberta, sem token, `.rej` enorme truncado); `runner_prep.sh` com os três cenários de limpeza (espaço sobrando, escalonamento, `full`); aritmética de `-j`. Os dois JSON dos ponteiros foram baixados do GitHub e têm `kernel.version` e `kernel.run`. **Não verificado:** a renderização dos badges (shields.io inacessível no ambiente de teste) e nenhuma run real no GitHub.

**Como ajustar (T26):** veja a linha `💾 … free` e o aviso de escalonamento no passo *Wait for Disk Cleanup*: se o aviso aparecer em **toda** run, use `FREE_DISK_LEVEL=full`; se nunca aparecer e sobrar muito espaço no passo *Disk Usage*, `lean` basta (e `DISK_NEED_GB` pode baixar).

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
