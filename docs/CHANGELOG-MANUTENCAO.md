# Changelog de manutenção — SAGA-Build

Registro de cada mudança de infraestrutura (workflows, scripts, docs): **o quê**, **por quê** e **como**.
Mais recente primeiro. Atualizado a cada patch aplicado. Plano completo: 30 tarefas (T1–T30).

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
