# Pin Scout e checkpoint de pins

Mantém ReSukiSU, SukiSU, KernelSU-Next e SuSFS atualizados sem quebrar o build.

## Conceitos (`kernel/android14-6.1-lts/manifest.json`)
Para cada componente: **`good`** (último commit que compilou) e **`bad`** (lista de commits que falharam). O build normal usa sempre o `good`.

## Fluxo (a cada 6 h, `pin-scout.yml`)
1. **Pré-check** (`scout_precheck.sh`): compara o topo da branch de cada componente com o manifest (`git ls-remote`). Se nada for novo, **para aqui** e não gasta runner. Modo manual `force` ignora o pré-check. Se o pré-check falhar, segue (fail-open).
2. Dispara o `build.yml` em **Warm Run** com `test_candidates=true`.
3. **`scout.sh`** decide, por componente, entre o pin (`good`) e o candidato (topo da branch). Só testa commits que não estão em `bad`.
4. A build roda com o candidato.
5. **`engine.sh`** (sempre, mesmo se falhar):
   - sucesso → o candidato vira `good`;
   - falha → o candidato entra em `bad` e o `good` não muda (**isso é o rollback**).
   Grava o `manifest.json` com *fetch → rebase → push* repetido, porque as variantes rodam em paralelo.
6. O commit automático (`chore: bump …` / `chore: mark …`) chega ao Telegram sem som.

## Regras de decisão (iguais em `scout.sh` e `scout_precheck.sh`)
| Situação | Testa? |
|---|---|
| topo == `good` e `good` não está em `bad` | não (em dia) |
| topo == `good` e `good` está em `bad` | sim (revalida) |
| topo está em `bad` e existe `good` | não |
| topo está em `bad` e **não** existe `good` | sim (evita deadlock) |
| topo novo | sim |
| falha ao consultar o upstream | não (mantém o pin) |

## Manutenção
- A lista `COMPONENTS` de `scout_precheck.sh` espelha o `scout.sh`; mude os dois juntos.
- Para reverter um pin à mão, edite `good`/`bad` no `manifest.json` e comite.
