# Post unificado do Telegram

Um modelo só para o **canal** e o **SAGA CHAT**: título, Download por variante, bloco **Features** expansível, changelog, links, bug report e hashtags. Gerado por `release/telegram/unified_caption.py`, enviado por `release/telegram/channel_post.sh` (job *Notify Channel*, só no modo **Release**).

## Como fica (perfil Default_Addons)

Recolhido (como chega):
```
┌──────────────────────────────────────────────┐
│  ▒▒▒▒▒▒▒▒▒▒▒▒  banner (prévia grande)  ▒▒▒▒▒▒▒▒▒▒▒▒  │
├──────────────────────────────────────────────┤
│ SAGA | Build | 6.1.190                       │
│ GKI Kernel | Android 14 | Linux 6.1.x        │
│                                              │
│ ┃ 📥 Download                                │
│ ┃ • Vanilla                                  │
│ ┃ • ResukiSU                                 │
│ ┃ • SukiSU                                   │
│ ┃ • KSUNext                                  │
│                                              │
│ ┃ ✨ Features                                │
│ ┃ Build Information                          │
│ ┃ Kernel: Linux 6.1.190                  ⌄   │
│                                              │
│ ┌ Changelog ───────────────────────────────┐ │
│ │ - Fix X                                  │ │
│ │ - Add Y                                  │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ Commits | Workflows                          │
│                                              │
│ Found a bug? Let's discuss it in SAGA CHAT   │
│                                              │
│ #GKI #SAGAKernel                             │
└──────────────────────────────────────────────┘
```

Expandido (ao tocar em Features):
```
│ ┃ ✨ Features                                │
│ ┃ Build Information                          │
│ ┃ Kernel: Linux 6.1.190                      │
│ ┃ Build System: Make - Neutron               │
│ ┃ Compiler: Neutron Clang 21.0.0             │
│ ┃ LTO: THIN                                  │
│ ┃                                            │
│ ┃ Feature Flags                              │
│ ┃ Mountless Engine: ZeroMount                │
│ ┃ Re:Kernel: Disable                         │
│ ┃ Droidspaces: Enable                        │
│ ┃ LZ4+ZSTD: Enable                           │
│ ┃ LZ4KD: Enable                              │
│ ┃ MGLRU: Disable                             │
│ ┃ LE9UO v1.15: Enable                        │
│ ┃ Kasumi: Disable                            │
│ ┃ Kcompressd v0.5: Enable                    │
│ ┃ Zram_ir v1: Disable                        │
│ ┃                                            │
│ ┃ SAGA Features                              │
│ ┃ • CONFIG_HZ: 250hz                         │
│ ┃ • Bore - 6.8.0 (backport)                  │
│ ┃ • ADIOS - 3.3.5-SAGA                       │
│ ┃ • BBRv3                                    │
│ ┃ • BBG                                      │
│ ┃ • NTSync                                   │
```

## Perfil CC_Addons
O kernel passa a se chamar **SAGA_CC**, cada variante ganha ` - CC` e as hashtags ganham `#CCKernel`:
```
│ SAGA_CC | Build | 6.1.190                    │
│ ┃ 📥 Download                                │
│ ┃ • Vanilla - CC                             │
│ ┃ • ResukiSU - CC                            │
│ ┃ • SukiSU - CC                              │
│ ┃ • KSUNext - CC                             │
│ …                                            │
│ ┃ • BORE Warp                                │
│ ┃ • CC Governor                              │
│ ┃ • Clutch Signals                           │
│ ┃ • ADIOS Clutch                             │
│ #GKI #SAGAKernel #CCKernel                   │
```
Os zips seguem o mesmo padrão: `SAGA-6.1.190-RESUKISU+SUSFS-R5.zip` (Default) e `SAGA_CC-6.1.190-RESUKISU+SUSFS-R5.zip` (CC).

## Como é enviado
1. `sendMessage` com o texto completo (até 4096 caracteres), prévia do banner **acima** do texto.
2. Se falhar, `sendPhoto` com o banner e a versão curta (até 1024, sem o bloco Features).
3. O mesmo post vai para o canal e para o chat; se algum falhar, o job falha (alto e claro).

## Ajustes
| O quê | Como |
|---|---|
| Banner da prévia | variável `TELEGRAM_BANNER_URL` (padrão: `banner.jpg` deste repo no `raw.githubusercontent.com`; o repo precisa ser público) |
| Prefixo dos assets no SAGA-Releases | `SAGA_ASSET_KEEP_PREFIX=true` publica `SAGA_CC-...`; o padrão mantém `SAGA-...` para não mudar o contrato do app de OTA |
| Voltar ao estilo com tabelas | em `channel_post.sh`, tire o `# ` do bloco **DISABLED** e comente o bloco **UNIFIED POST** |
| Nome/versão dos addons no post | `addon.meta` e o nome do patch (`...-vX.Y.patch`); ver `ADDONS.md` |

O post por build, enviado ao tópico de CI, continua no formato antigo (blocos de código), agora com o título `SAGA_CC` nos builds CC.
