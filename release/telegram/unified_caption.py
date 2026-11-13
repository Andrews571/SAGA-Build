#!/usr/bin/env python3
"""
Post UNIFICADO do kernel SAGA (canal + SAGA CHAT): modelo original do chat
(titulo, Download por variante, Changelog, rastreio, bug report, hashtags)
com um bloco "Features" EXPANSIVEL (blockquote expandable do Telegram) que traz
Build Information, Feature Flags e SAGA Features, com a versao de cada addon.

Uso:
    unified_caption.py FULL_FILE SHORT_FILE

    FULL_FILE  : texto completo (<= 4096), com o bloco Features expansivel
    SHORT_FILE : o mesmo texto SEM o bloco Features (<= 1024), usado no
                 fallback "foto + legenda" se o envio do texto completo falhar

Le o mesmo ambiente do caption.py (VARIANT_LINKS_JSON, ADDONS, LINUX_VER ...) e
tambem ADDON_PROFILE: com "CC_Addons" o kernel se chama SAGA_CC e as variantes
ganham o sufixo " - CC" (ex: "Vanilla - CC").
"""
import json
import os
import sys
from datetime import datetime

import caption as legacy
import rich_caption as rich

MESSAGE_LIMIT = 4096

# Nomes dos addons do perfil CC (o caption.py so conhece os do perfil padrao)
for _token, _name in {
    "cc-governor": "CC Governor",
    "clutch-signals": "Clutch Signals",
    "adios-clutch": "ADIOS Clutch",
    "bore-warp": "BORE Warp",
}.items():
    legacy.ADDON_DISPLAY_NAMES.setdefault(_token, _name)


def esc(text):
    return legacy.mdv2_escape(str(text))


def is_cc(env):
    return env.get("ADDON_PROFILE", "").strip() == "CC_Addons"


def kernel_name(env):
    return "SAGA_CC" if is_cc(env) else "SAGA"


def variant_label(key, env):
    """Nome da variante no link de download; no perfil CC ganha ' - CC'."""
    base = legacy.VARIANT_BASE_DISPLAY.get(key, esc(key))
    return base + (" \\- CC" if is_cc(env) else "")


def _load_json_env(env, name):
    try:
        raw = env.get(name, "")
        return json.loads(raw) if raw else {}
    except Exception:
        return {}


# ---------------------------------------------------------------------------
# Bloco "Features" (expansivel)
# ---------------------------------------------------------------------------
def _addon_version_text(token, addons_root):
    name = legacy.ADDON_DISPLAY_NAMES.get(token, token)
    ver = rich.discover_addon_version(token, addons_root)
    return f"{name} - {ver}" if ver else name


def feature_lines(env, addons_root):
    """Linhas de 'SAGA Features' com a versao na frente do nome, quando existir."""
    tokens = set(t for t in env.get("ADDONS", "").split(",") if t)
    lines = []
    for line in legacy.build_feature_lines(env):
        # o kernel reporta o ADIOS como "<versao>-SAGA"; mostramos igual
        if line.startswith("ADIOS - ") and not line.endswith("SAGA"):
            line += "-SAGA"
        lines.append(line)

    # addons do perfil CC
    for token in ("bore-warp", "cc-governor", "clutch-signals", "adios-clutch"):
        if token not in tokens:
            continue
        text = _addon_version_text(token, addons_root)
        if token == "adios-clutch":
            text += "-SAGA-Clutch" if " - " in text else ""
        lines.append(text)
    return lines


def build_features_block(env, addons_root):
    """Retorna o blockquote EXPANSIVEL (MarkdownV2) ou '' se nao houver o que mostrar."""
    tokens = [t for t in env.get("ADDONS", "").split(",") if t]
    linux_ver = env.get("LINUX_VER", "N/A")

    rows = ["✨ *Features*"]

    # --- Build Information -------------------------------------------------
    rows.append("*Build Information*")
    rows.append(f"Kernel: Linux {esc(linux_ver)}")
    if env.get("BUILD_SYSTEM_DISPLAY", "").strip():
        rows.append(f"Build System: {esc(env['BUILD_SYSTEM_DISPLAY'].strip())}")
    if env.get("COMPILER_STRING", "").strip():
        rows.append(f"Compiler: {esc(env['COMPILER_STRING'].strip())}")
    if env.get("LTO_MODE", "").strip():
        rows.append(f"LTO: {esc(env['LTO_MODE'].strip())}")
    rows.append("")

    # --- Feature Flags (addons liga/desliga) ---------------------------------
    rows.append("*Feature Flags*")
    mountless = next((t for t in legacy.MOUNTLESS_ADDON_TOKENS if t in tokens), None)
    if mountless:
        shown = rich.display_with_version(mountless, addons_root)
    else:
        shown = "None"
    rows.append(f"Mountless Engine: {esc(shown)}")
    for token in legacy.TOGGLE_ADDON_ORDER:
        name = rich.display_with_version(token, addons_root)
        state = "Enable" if token in tokens else "Disable"
        rows.append(f"{esc(name)}: {state}")
    rows.append("")

    # --- SAGA Features ---------------------------------------------------------
    features = feature_lines(env, addons_root)
    if features:
        rows.append("*SAGA Features*")
        for line in features:
            rows.append(f"• {esc(line)}")
    else:
        while rows and rows[-1] == "":
            rows.pop()

    # blockquote expansivel: 1a linha "**>", demais ">", ultima termina com "||"
    out = []
    for i, row in enumerate(rows):
        out.append(("**>" if i == 0 else ">") + row)
    out[-1] += "||"
    return "\n".join(out)


# ---------------------------------------------------------------------------
# Post
# ---------------------------------------------------------------------------
def build_sections(env, links, features_block):
    kernel_ver = env.get("KERNEL_VERSION", "")
    linux_ver = env.get("LINUX_VER", "N/A")
    android_ver = legacy.KERNEL_VERSION_TO_ANDROID.get(kernel_ver, "?")
    major_minor = ".".join(linux_ver.split(".")[:2]) + ".x"

    sections = [
        f"*{esc(kernel_name(env))} \\| Build \\| {esc(linux_ver)}*\n"
        f"*GKI Kernel \\| Android {esc(android_ver)} \\| Linux {esc(major_minor)}*"
    ]

    download = ["> 📥 *Download*"]
    for key, link in links.items():
        download.append(f"> • [{variant_label(key, env)}]({legacy.mdv2_escape_url(link)})")
    sections.append("\n".join(download))

    if features_block:
        sections.append(features_block)

    changelog_raw = env.get("CHANGELOG", "").strip()
    if changelog_raw:
        entries = [e.strip() for e in changelog_raw.split(";") if e.strip()]
        body = "\n".join(f"- {legacy.mdv2_code_escape(e)}" for e in entries)
        sections.append(legacy.truncate("```Changelog\n" + body + "```", legacy.CHANGELOG_MAX_LEN))

    base = f"{env.get('GITHUB_SERVER_URL', '')}/{env.get('GITHUB_REPOSITORY', '')}"
    commits_url = f"{base}/commits/main/"
    run_url = f"{base}/actions/runs/{env.get('GITHUB_RUN_ID', '')}"
    sections.append(
        "[Commits]({}) \\| [Workflows]({})".format(
            legacy.mdv2_escape_url(commits_url), legacy.mdv2_escape_url(run_url)
        )
    )

    group_url = legacy.mdv2_escape_url("https://t.me/sagakernel")
    sections.append(f"Found a bug? Let's discuss it in [SAGA CHAT]({group_url})")

    tags = "\\#GKI \\#SAGAKernel"
    if is_cc(env):
        tags += " \\#CCKernel"
    sections.append(tags)
    return sections


def main():
    if len(sys.argv) < 3:
        print("uso: unified_caption.py FULL_FILE SHORT_FILE", file=sys.stderr)
        sys.exit(2)
    env = os.environ
    addons_root = env.get("SAGA_ADDONS_DIR", "kernel/addons")
    links = _load_json_env(env, "VARIANT_LINKS_JSON")

    features = build_features_block(env, addons_root)

    full = "\n\n".join(build_sections(env, links, features))
    short = "\n\n".join(build_sections(env, links, ""))
    full = legacy.truncate(full, MESSAGE_LIMIT)
    short = legacy.truncate(short, legacy.CAPTION_LIMIT)

    with open(sys.argv[1], "w") as f:
        f.write(full)
    with open(sys.argv[2], "w") as f:
        f.write(short)
    print(f"[info] unified_caption: full={len(full)} chars, short={len(short)} chars ✅", flush=True)


if __name__ == "__main__":
    main()
