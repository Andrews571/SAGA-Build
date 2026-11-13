# Como adicionar um addon

## Estrutura
```
kernel/addons/<nome>/<nome>.sh        # obrigatório
kernel/addons/<nome>/postbuild.sh     # opcional: roda DEPOIS da compilação
kernel/addons/<nome>/*.patch          # patches usados pelo script
```
**Pasta, script e token usados no `build.yml` precisam ter exatamente o mesmo nome.** O passo *Preflight — Validate Addons* falha em ~1 s se algum não bater.

## Como o script é executado
`build.sh` faz `source` do `<nome>.sh` (não é um processo separado), então ele já tem:
- `SAGA_PATCH_DIR` (raiz deste repo) e `KERNEL_SRC` (fonte do kernel);
- as funções `log "mensagem"` e `error "mensagem"` (`error` aborta a build).

Padrão recomendado (veja `kernel/addons/le9uo/le9uo.sh`): conferir se o patch já foi aplicado (`patch --dry-run --reverse`), aplicar se não foi, e falhar com `error` se não aplicar.

## `addon.meta` (obrigatório)
Cada addon tem um `kernel/addons/<nome>/addon.meta` (`chave=valor`, uma por linha). O **Lint** barra o commit se faltar ou estiver inválido.

| Chave | Significado |
|---|---|
| `name` | igual ao nome da pasta |
| `desc` | o que o addon faz (1 linha) |
| `mode` | `local` (código do SAGA), `vendored-patch` (cópia de patch do upstream), `fetch-latest` (baixa o upstream a cada build), `git-clone` (clona a cada build) |
| `upstream` | URL do repositório de origem (vazio se for local) |
| `license` | licença do upstream (`?` se não confirmada: sem LICENSE/SPDX) |
| `track` | `none`, `branch` (topo da branch) ou `path` (último commit que toca `track_path`) |
| `track_ref` / `track_path` | branch (ou `HEAD`) e, para `path`, o arquivo/pasta que o addon baixa |
| `seen` / `seen_at` | último commit do upstream **já revisado** e a data |
| `notes` | observações livres |

**Vigilância:** o Pin Scout compara o upstream com `seen` a cada 6 h e mantém **uma** issue `📦 Addon upstream updates` (rótulo `addon-upstream`), que fecha sozinha quando tudo está em dia. Só avisa: não muda build nem pins. Depois de olhar a mudança, marque como revisado e comite:
```bash
bash kernel/checkpoint/addon_watch.sh accept <addon>   # ou: accept all
bash kernel/checkpoint/addon_watch.sh doc > docs/ADDONS-LISTA.md   # regenera a tabela
```
`seen` é o commit do upstream na data da revisão, **não** necessariamente o commit de onde veio um patch `vendored-patch`.

## Passo a passo
1. Crie `kernel/addons/<nome>/<nome>.sh` (+ patches) e o `addon.meta`. Para preencher `seen`: `bash kernel/checkpoint/addon_watch.sh accept <nome>`.
2. Em `.github/workflows/build.yml`, passo **Build Variant Matrix**, acrescente o token à lista `ADDONS` (a ordem importa: um addon que depende de outro vem depois). Se for opcional, crie um `input` booleano e o prefixo `${ADDON_X}` como os existentes.
3. Se conflitar com outro addon, registre no *conflict matrix* de `run_addons()` em `build.sh`.
4. Para aparecer como toggle no post do Telegram, inclua o nome em `release/telegram/caption.py` (`TOGGLE_ADDON_ORDER` e o mapa de rótulos).
5. Teste com **Dry Run** e depois **Warm Run** numa branch.
6. Regenere `docs/ADDONS-LISTA.md` (comando acima) e registre a mudança em `CHANGELOG-MANUTENCAO.md`.

## Boas práticas
- Um addon, uma responsabilidade; patches versionados no nome (`...-android14-6.1-v1.15.patch`).
- Documente no cabeçalho do script: origem (upstream), versão e interações conhecidas.
