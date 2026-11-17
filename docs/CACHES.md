# Caches de build

Ficam no release `cache` deste repositório (assets `*.tar.zst`), fora do limite de 10 GB do Actions Cache.

| Cache | Nome do asset | Conteúdo |
|---|---|---|
| ccache | `ccache-data-<kernel>-<variante>[+SUSFS]-<CLANG>[-<LTO>]-<branch>.tar.zst` | objetos compilados |
| LTO (só `THIN`) | `lto-data-…` (mesmo padrão) | cache do ThinLTO (`/dev/shm/ldcache`) |

Cada variante restaura e salva o **seu** asset. O relatório do passo *Ccache Stats* mostra o hit rate (✅ ≥ 90% com cache quente; um cache frio logo após `arsenal update` é esperado).

## Semeadura (T24)
Quando o asset próprio **não existe** (branch nova, variante nova) ou está corrompido, o restore tenta, nesta ordem, caches "irmãos" em vez de começar do zero:
1. a mesma variante na branch padrão (`main`);
2. `VANILLA` da mesma branch;
3. `VANILLA` da branch padrão.

É seguro: ccache e o cache do ThinLTO são endereçados por conteúdo, então uma entrada de outra variante só é usada quando o arquivo compilado é idêntico. O log mostra `SEEDED from sibling cache` e um aviso `::notice`. O asset próprio é criado normalmente no fim da build. **Não** muda nada quando o cache próprio existe.

## Por que não "compilar uma vez e reaproveitar entre variantes" (T25)
As 4 variantes já rodam **em paralelo** e já reaproveitam o que é igual por meio do ccache. Um job-base que compile o kernel e entregue o diretório `out/` às variantes criaria uma dependência em série: tempo total = tempo do base + (recompilar os arquivos que o KSU altera + relink/LTO de cada variante), maior que os ~22 min de hoje num cache frio e sem ganho relevante num cache quente. Só economizaria minutos de runner, que em repositório público não custam nada. Além disso, mover vários GB de `out/` entre jobs e confiar na compilação incremental do kbuild (timestamps) aumenta o risco de um build "quase certo". Estimativa baseada na estrutura do fluxo, **não medida**: se um dia o tempo de uma build com cache quente passar de ~15 min, vale medir de novo.
