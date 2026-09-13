"""
rich_caption.py

Constrói o payload de um Telegram Rich Message (sendRichMessage, Bot API
10.1+) para o post do canal, no mesmo estilo usado pelo chainonyourdoor
("Luminaire Protocol"): tabelas nativas + seção recolhível "What's Inside?"
em vez de caption MarkdownV2 + link pra Telegraph.

Não inventa nenhum addon/versão/estado novo — importa e reaproveita
diretamente as constantes e funções de caption.py (ADDON_DISPLAY_NAMES,
TOGGLE_ADDON_ORDER, FEATURE_ADDON_TOKENS, MOUNTLESS_ADDON_TOKENS,
build_feature_lines, VARIANT_DISPLAY, KERNEL_VERSION_TO_ANDROID) para que
os dois caminhos (caption antiga e rich message nova) nunca fiquem
dessincronizados quanto a QUAIS addons existem ou como são detectados.

O estado Enable/Disable de cada addon sai de env["ADDONS"], a mesma lista
gerada pelo job "Prepare Arsenal" do build.yml a partir dos inputs do
workflow_dispatch daquele run especifico — por isso varia build a build,
igual o caption.py de hoje.

Uso (mesmo padrao de main() em caption.py):
    python3 rich_caption.py <arquivo_saida.json>

Espera as mesmas env vars que build_channel_caption() já usa hoje
(LINUX_VER, KERNEL_VERSION, ADDONS, BORE_VERSION, ADIOS_VERSION, TICK_RATE,
BUILD_SYSTEM_DISPLAY, COMPILER_STRING, LTO_MODE, CHANGELOG,
VARIANT_LINKS_JSON, VARIANT_VERSIONS_JSON, GITHUB_*), lidas de os.environ
em main() do mesmo jeito que caption.py já faz.
"""

import json
import os
import sys

import caption as legacy


# ---------------------------------------------------------------------------
# Blocos Rich Message — dicts simples (JSON-serializáveis), no formato que a
# Bot API espera em InputRichMessage/InputRichBlock*. Validado contra o
# schema real do aiogram 3.31 (RichBlockTable/RichBlockTableCell/
# RichBlockDetails/RichTextButton) antes de entrar em produção.
# ---------------------------------------------------------------------------
def badge(text, style):
    """Badge colorido não-clicável: style em success/danger/primary."""
    return {"type": "button", "button": {"text": text, "style": style, "disabled": {}}}


def link_button(text, url):
    """Texto azul clicável, sem borda (estilo 'link')."""
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


def footer(text):
    return {"type": "footer", "text": text}


# ---------------------------------------------------------------------------
# Montagem do post
# ---------------------------------------------------------------------------
def build_rich_message(env, variant_links, variant_versions=None):
    variant_versions = variant_versions or {}

    kernel_ver  = env.get("KERNEL_VERSION", "")
    linux_ver   = env.get("LINUX_VER", "N/A")
    android_ver = legacy.KERNEL_VERSION_TO_ANDROID.get(kernel_ver, "?")
    major_minor = ".".join(linux_ver.split(".")[:2]) + ".x" if linux_ver != "N/A" else "N/A"

    addon_tokens = [t for t in env.get("ADDONS", "").split(",") if t]

    # --- Build Information --------------------------------------------
    # Kernel vem de LINUX_VER. Build System/Compiler/LTO vêm agora dos
    # JSONs por variante (mesmo mecanismo do bore_version/adios_version) —
    # propagados por telegram.sh e agregados por channel_post.sh. A
    # checagem abaixo só é defensiva (build antigo sem o campo, etc.), não
    # significa que o dado "não dá pra usar".
    build_rows = [kv_row("Kernel", f"Linux {linux_ver}")]
    if env.get("BUILD_SYSTEM_DISPLAY", "").strip():
        build_rows.append(kv_row("Build System", env["BUILD_SYSTEM_DISPLAY"]))
    if env.get("COMPILER_STRING", "").strip():
        build_rows.append(kv_row("Compiler", env["COMPILER_STRING"]))
    if env.get("LTO_MODE", "").strip():
        build_rows.append(kv_row("LTO", env["LTO_MODE"]))

    # --- Feature Flags (toggle add-ons) — Enable/Disable vem de ADDONS,
    # ou seja, varia conforme os inputs do workflow_dispatch daquele run.
    mountless_name = None
    for token in legacy.MOUNTLESS_ADDON_TOKENS:
        if token in addon_tokens:
            mountless_name = legacy.ADDON_DISPLAY_NAMES.get(token, token)
            break

    flag_rows = [
        kv_row("Mountless Engine", badge(mountless_name, "primary") if mountless_name else "None"),
    ]
    for token in legacy.TOGGLE_ADDON_ORDER:
        name = legacy.ADDON_DISPLAY_NAMES.get(token, token)
        enabled = token in addon_tokens
        flag_rows.append(
            kv_row(name, badge("Enable" if enabled else "Disable", "success" if enabled else "danger"))
        )

    # --- Features sempre-ativas com versão (CONFIG_HZ, BORE, ADIOS,
    # BBRv3, BBG, NTSync) — mesma lista de build_feature_lines(), já usada
    # hoje pela caption antiga e pela página do Telegraph.
    feature_lines = legacy.build_feature_lines(env)
    feature_rows = [[cell(line, colspan=2)] for line in feature_lines]

    # --- Root Solutions — uma linha por variante realmente builada
    # (variant_links vem de VARIANT_LINKS_JSON, montado pelo channel_post.sh
    # a partir dos artefatos que existem de fato nesse run).
    root_rows = []
    for variant_key, link in variant_links.items():
        display = legacy.VARIANT_DISPLAY.get(variant_key, variant_key)
        version = variant_versions.get(variant_key, "")
        root_rows.append(kv_row(link_button(display, link), version or "—"))

    inner = [table("Build Information", build_rows)]
    if len(flag_rows) > 1 or mountless_name:
        inner.append(table("Feature Flags", flag_rows))
    if feature_rows:
        inner.append(table("SAGA Features", feature_rows))
    if root_rows:
        inner.append(table("Root Solutions", root_rows))

    changelog_raw = env.get("CHANGELOG", "").strip()
    if changelog_raw:
        entries = [e.strip() for e in changelog_raw.split(";") if e.strip()]
        if entries:
            inner.append(heading("Changelog", size=3))
            inner.append(bullet_list(entries))

    commit_short = env.get("GITHUB_SHA", "")[:7]
    commit_url = "{}/{}/commit/{}".format(
        env.get("GITHUB_SERVER_URL", ""), env.get("GITHUB_REPOSITORY", ""), env.get("GITHUB_SHA", "")
    )
    run_url = "{}/{}/actions/runs/{}".format(
        env.get("GITHUB_SERVER_URL", ""), env.get("GITHUB_REPOSITORY", ""), env.get("GITHUB_RUN_ID", "")
    )
    group_url = "https://t.me/sagakernel"

    footer_text = [
        link_button(f"#{commit_short}", commit_url),
        "  |  ",
        link_button(f"Run #{env.get('GITHUB_RUN_ID', '')}", run_url),
        "  |  ",
        link_button("Bug? SAGA CHAT", group_url),
    ]

    blocks = [
        heading(f"SAGA | Build | {linux_ver}", size=1),
        paragraph(badge(f"GKI Kernel | Android {android_ver} | Linux {major_minor}", "primary")),
        divider(),
        details("📦 What's Inside?", inner, is_open=True),
        footer(footer_text),
    ]
    return {"blocks": blocks}


def main():
    out_path = sys.argv[1]
    env = os.environ

    variant_links_json = env.get("VARIANT_LINKS_JSON", "")
    try:
        variant_links = json.loads(variant_links_json) if variant_links_json else {}
    except Exception:
        variant_links = {}

    variant_versions_json = env.get("VARIANT_VERSIONS_JSON", "")
    try:
        variant_versions = json.loads(variant_versions_json) if variant_versions_json else {}
    except Exception:
        variant_versions = {}

    rich_message = build_rich_message(env, variant_links, variant_versions)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(rich_message, f, ensure_ascii=False)

    print("[info] rich_caption: rich message written ✅", flush=True)


if __name__ == "__main__":
    main()
