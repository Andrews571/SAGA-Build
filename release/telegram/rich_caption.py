"""
rich_caption.py

Constroi o payload de um Telegram Rich Message (sendRichMessage, Bot API
10.1+) para o post do canal — post UNICO (banner embutido + tabelas + duas
abas recolhiveis), no lugar de sendPhoto+caption MarkdownV2.

Nao inventa nenhum addon/versao/estado novo — importa e reaproveita
diretamente as constantes e funcoes de caption.py (ADDON_DISPLAY_NAMES,
TOGGLE_ADDON_ORDER, FEATURE_ADDON_TOKENS, MOUNTLESS_ADDON_TOKENS,
build_feature_lines, VARIANT_DISPLAY, KERNEL_VERSION_TO_ANDROID) para que
caption antiga e rich message nunca fiquem dessincronizadas quanto a QUAIS
addons existem ou como sao detectados.

Estrutura do post (um unico sendRichMessage, banner incluido):
  [Photo: banner]
  SAGA | Build | X.Y.Z
  [tag] GKI Kernel | Android N | Linux X.Y.x
  --------------------------------------------
  v 📦 What's Inside?      (aberta por padrao)
      Build Information | Feature Flags | SAGA Features
  > 🔗 Features             (fechada por padrao)
      Root Solutions (Download) | Changelog | Commits|Workflows | Bug? | hashtags
  (isto e exatamente o que a secao "Features" do post MarkdownV2 antigo
  mostrava — so que agora dentro de uma aba recolhivel do rich message,
  em vez de sempre visivel)

Estado Enable/Disable de cada addon sai de env["ADDONS"] (gerado pelo job
"Prepare Arsenal" do build.yml a partir dos inputs do workflow_dispatch
daquele run) — varia build a build, igual o caption.py de hoje.

Versao automatica nos addons do Feature Flags: cada addon habilitado tem
seu diretorio em kernel/addons/<token>/ vasculhado por um arquivo de patch
terminando em "-vX.Y[.Z].patch" (mesma convencao que bore.sh/adios.sh ja
usam pra extrair BORE_VERSION/ADIOS_VERSION). Addons sem arquivo nesse
padrao (bbg, bbrv3, droidspaces, kasumi, lz4kd, lz4zstd, mglru, nomount,
ntsync, rekernel, zeromount — conferido no repo) aparecem sem versao, sem
inventar numero.

Uso:
    python3 rich_caption.py <arquivo_saida.json>

Env vars: as mesmas que build_channel_caption() ja usa (LINUX_VER,
KERNEL_VERSION, ADDONS, BORE_VERSION, ADIOS_VERSION, TICK_RATE,
BUILD_SYSTEM_DISPLAY, COMPILER_STRING, LTO_MODE, CHANGELOG,
VARIANT_LINKS_JSON, VARIANT_VERSIONS_JSON, GITHUB_*) + BANNER_PATH e
opcionalmente SAGA_ADDONS_DIR (default "kernel/addons", relativo ao CWD —
o job notify-channel faz actions/checkout, entao o caminho existe).
"""

import glob
import json
import os
import re
import sys

import caption as legacy


# ---------------------------------------------------------------------------
# Blocos Rich Message — dicts simples (JSON-serializaveis), validados contra
# o schema real da Bot API via aiogram 3.31 antes de entrar em producao.
# ---------------------------------------------------------------------------
def badge(text, style):
    """Badge colorido nao-clicavel: style em success/danger/primary."""
    return {"type": "button", "button": {"text": text, "style": style, "disabled": {}}}


def link_button(text, url):
    """Texto azul clicavel, sem borda (estilo 'link')."""
    return {"type": "button", "button": {"text": text, "style": "link", "url": url}}


def cell(text, is_header=False, colspan=1, align="left"):
    return {"align": align, "valign": "middle", "text": text, "is_header": is_header, "colspan": colspan}


def header_row(title):
    return [cell(title, is_header=True, colspan=2, align="center")]


def kv_row(key, value):
    return [cell(key), cell(value)]


def table(title, rows, is_bordered=True):
    return {"type": "table", "cells": [header_row(title), *rows], "is_bordered": is_bordered}


def details(summary, blocks, is_open=False):
    return {"type": "details", "summary": summary, "blocks": blocks, "is_open": is_open}


def heading(text, size=3):
    return {"type": "heading", "text": text, "size": size}


def paragraph(text):
    return {"type": "paragraph", "text": text}


def divider():
    return {"type": "divider"}


def bullet_list(items):
    return {"type": "list", "items": [{"blocks": [paragraph(i)]} for i in items]}


def photo(attach_name):
    return {"type": "photo", "photo": {"type": "photo", "media": f"attach://{attach_name}"}}


# ---------------------------------------------------------------------------
# Versao automatica por addon (a partir do nome do arquivo de patch)
# ---------------------------------------------------------------------------
ADDON_DIR_OVERRIDES = {"zram_ir": "zram-ir"}  # token na ADDONS != nome da pasta
_VERSION_RE = re.compile(r"-v([0-9]+(?:\.[0-9]+)*)\.patch")


def discover_addon_version(token, addons_root):
    """Procura kernel/addons/<dir>/*-vX.Y[.Z].patch* e devolve 'X.Y[.Z]' ou None."""
    dirname = ADDON_DIR_OVERRIDES.get(token, token)
    if not addons_root or not os.path.isdir(os.path.join(addons_root, dirname)):
        return None
    best = None
    for path in glob.glob(os.path.join(addons_root, dirname, "*.patch*")):
        m = _VERSION_RE.search(os.path.basename(path))
        if m:
            best = m.group(1)
    return best


def display_with_version(token, addons_root):
    name = legacy.ADDON_DISPLAY_NAMES.get(token, token)
    ver = discover_addon_version(token, addons_root)
    return f"{name} v{ver}" if ver else name


# ---------------------------------------------------------------------------
# Montagem do post
# ---------------------------------------------------------------------------
def build_rich_message(env, variant_links, variant_versions=None, addons_root="kernel/addons"):
    variant_versions = variant_versions or {}

    kernel_ver  = env.get("KERNEL_VERSION", "")
    linux_ver   = env.get("LINUX_VER", "N/A")
    android_ver = legacy.KERNEL_VERSION_TO_ANDROID.get(kernel_ver, "?")
    major_minor = ".".join(linux_ver.split(".")[:2]) + ".x" if linux_ver != "N/A" else "N/A"

    addon_tokens = [t for t in env.get("ADDONS", "").split(",") if t]

    # --- Build Information ----------------------------------------------
    build_rows = [kv_row("Kernel", f"Linux {linux_ver}")]
    if env.get("BUILD_SYSTEM_DISPLAY", "").strip():
        build_rows.append(kv_row("Build System", env["BUILD_SYSTEM_DISPLAY"]))
    if env.get("COMPILER_STRING", "").strip():
        build_rows.append(kv_row("Compiler", env["COMPILER_STRING"]))
    if env.get("LTO_MODE", "").strip():
        build_rows.append(kv_row("LTO", env["LTO_MODE"]))

    # --- Feature Flags (toggle add-ons) -----------------------------------
    # Enable/Disable vem de ADDONS -> varia por run. Nome ganha "vX.Y.Z"
    # automaticamente quando o addon tem patch versionado (ver acima).
    mountless_token = next((t for t in legacy.MOUNTLESS_ADDON_TOKENS if t in addon_tokens), None)
    mountless_name = display_with_version(mountless_token, addons_root) if mountless_token else None

    flag_rows = [kv_row("Mountless Engine", badge(mountless_name, "primary") if mountless_name else "None")]
    for token in legacy.TOGGLE_ADDON_ORDER:
        enabled = token in addon_tokens
        name = display_with_version(token, addons_root) if enabled else legacy.ADDON_DISPLAY_NAMES.get(token, token)
        flag_rows.append(kv_row(name, badge("Enable" if enabled else "Disable", "success" if enabled else "danger")))

    # --- Features sempre-ativas com versao (CONFIG_HZ, BORE, ADIOS, BBRv3,
    # BBG, NTSync) — mesma lista de build_feature_lines(), ja usada hoje.
    feature_lines = legacy.build_feature_lines(env)
    feature_rows = [[cell(line, colspan=2)] for line in feature_lines]

    whats_inside = [table("Build Information", build_rows)]
    if len(flag_rows) > 1 or mountless_name:
        whats_inside.append(table("Feature Flags", flag_rows))
    if feature_rows:
        whats_inside.append(table("SAGA Features", feature_rows))

    # --- Aba "Features" (= secao "Features" do post antigo, agora recolhivel)
    features_tab = []

    root_rows = []
    for variant_key, link in variant_links.items():
        display = legacy.VARIANT_DISPLAY.get(variant_key, variant_key)
        version = variant_versions.get(variant_key, "")
        root_rows.append(kv_row(link_button(display, link), version or "—"))
    if root_rows:
        features_tab.append(table("Download", root_rows))

    changelog_raw = env.get("CHANGELOG", "").strip()
    if changelog_raw:
        entries = [e.strip() for e in changelog_raw.split(";") if e.strip()]
        if entries:
            features_tab.append(heading("Changelog", size=3))
            features_tab.append(bullet_list(entries))

    commit_short = env.get("GITHUB_SHA", "")[:7]
    commit_url = "{}/{}/commit/{}".format(
        env.get("GITHUB_SERVER_URL", ""), env.get("GITHUB_REPOSITORY", ""), env.get("GITHUB_SHA", "")
    )
    run_url = "{}/{}/actions/runs/{}".format(
        env.get("GITHUB_SERVER_URL", ""), env.get("GITHUB_REPOSITORY", ""), env.get("GITHUB_RUN_ID", "")
    )
    group_url = "https://t.me/sagakernel"

    if commit_short:
        features_tab.append(paragraph([link_button(f"#{commit_short}", commit_url), "  |  ",
                                        link_button("Workflow Run", run_url)]))
    features_tab.append(paragraph(["Found a bug? Let's discuss it in ", link_button("SAGA CHAT", group_url)]))
    features_tab.append(paragraph("#GKI #SAGAKernel"))

    blocks = []
    if env.get("BANNER_ATTACH_NAME", "").strip():
        blocks.append(photo(env["BANNER_ATTACH_NAME"]))
    blocks += [
        heading(f"SAGA | Build | {linux_ver}", size=1),
        paragraph(badge(f"GKI Kernel | Android {android_ver} | Linux {major_minor}", "primary")),
        divider(),
        details("📦 What's Inside?", whats_inside, is_open=True),
        details("🔗 Features", features_tab, is_open=False),
    ]
    return {"blocks": blocks}


def main():
    out_path = sys.argv[1]
    env = os.environ

    def load_json_env(name):
        raw = env.get(name, "")
        try:
            return json.loads(raw) if raw else {}
        except Exception:
            return {}

    variant_links = load_json_env("VARIANT_LINKS_JSON")
    variant_versions = load_json_env("VARIANT_VERSIONS_JSON")
    addons_root = env.get("SAGA_ADDONS_DIR", "kernel/addons")

    rich_message = build_rich_message(env, variant_links, variant_versions, addons_root)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(rich_message, f, ensure_ascii=False)

    print("[info] rich_caption: rich message written OK", flush=True)


if __name__ == "__main__":
    main()
