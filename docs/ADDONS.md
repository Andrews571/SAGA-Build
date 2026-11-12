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

## Passo a passo
1. Crie `kernel/addons/<nome>/<nome>.sh` (+ patches).
2. Em `.github/workflows/build.yml`, passo **Build Variant Matrix**, acrescente o token à lista `ADDONS` (a ordem importa: um addon que depende de outro vem depois). Se for opcional, crie um `input` booleano e o prefixo `${ADDON_X}` como os existentes.
3. Se conflitar com outro addon, registre no *conflict matrix* de `run_addons()` em `build.sh`.
4. Para aparecer como toggle no post do Telegram, inclua o nome em `release/telegram/caption.py` (`TOGGLE_ADDON_ORDER` e o mapa de rótulos).
5. Teste com **Dry Run** e depois **Warm Run** numa branch.
6. Registre a mudança em `CHANGELOG-MANUTENCAO.md`.

## Boas práticas
- Um addon, uma responsabilidade; patches versionados no nome (`...-android14-6.1-v1.15.patch`).
- Documente no cabeçalho do script: origem (upstream), versão e interações conhecidas.
