# Changelog automático dos releases

O changelog do post e do SAGA-Releases (`Changelog` no Telegram, `changelog` no `saga-release.json`) é montado sozinho a cada **Release** pelo job **Build Changelog** (`release/changelog.py`). Ele compara este release com o **release anterior do mesmo canal** (stable = `Default_Addons`, experimental = `CC_Addons`; o perfil `Optimized_Addons` ainda não tem canal e não publica Release) e escreve linhas curtas:

| Fonte | Exemplo de linha | Precisa fazer algo? |
|---|---|---|
| Texto manual do disparo (campo `changelog`) | `Fixed audio crackling` | só se quiser |
| **Trailer `Changelog:` nos commits** | `Added new CC Governor` | sim, ao commitar (opcional) |
| Versão do Linux | `Updated Linux 6.1.187 → 6.1.190` | não |
| Pins (ReSukiSU, SukiSU, KernelSU-Next, SuSFS) | `Updated ReSukiSU (548d1dd → 5d6d184)` | não |
| Addons | `Added Kasumi` · `Removed ADIOS` | não |
| Toolchain | `Updated toolchain: Neutron Clang 20.0.0 → 21.0.0` | não |

Sem nada novo, o bloco **Changelog** simplesmente não aparece no post.

## O trailer `Changelog:` (como usar)
É uma linha **no corpo do commit**, escrita só quando a mudança interessa a quem usa o kernel. Commits sem ela (CI, docs, refatoração, bump de pin) **não entram**: os commits são longos e técnicos demais para virar changelog.

```bash
git commit -m "feat: add CC governor with cluster-aware scaling and sysctl knobs" \
           -m "Changelog: Added new CC Governor"
```
No site do GitHub: o 1º campo é o título; no campo de descrição ("Add an optional extended description") escreva `Changelog: Added new CC Governor`.

Regras: uma linha por mudança; pode haver várias `Changelog:` no mesmo commit; escreva em inglês, curto, no passado ("Added…", "Fixed…", "Improved…"); `;` vira `,`; cada linha é cortada em 120 caracteres.

## Como o "desde o último release" é calculado
- O `saga-release.json` do release anterior guarda o commit (`kernel.commit`). O changelog lê os commits `<commit anterior>..HEAD`; se esse commit não existir mais (reescrita de histórico), usa a data `built_at`.
- Pins: compara o `manifest.json` daquele commit com o atual.
- Addons e toolchain: comparam com `addons` e `toolchain` do JSON anterior (o `toolchain` só existe a partir do release que incluiu o T21; o primeiro release depois disso não mostra a linha de toolchain).
- Primeiro release de um canal (sem anterior): só o texto manual.
- Máximo de 10 linhas; o excesso vira `+N more changes`.

Se o job falhar, o release usa o campo manual `changelog`, como antes.
