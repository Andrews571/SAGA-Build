import os
import sys
import json
from datetime import datetime


CAPTION_LIMIT = 1024
PUSH_TEXT_LIMIT = 4096  # sendMessage text limit — separate from the 1024
                         # sendDocument/sendPhoto caption limit above

KERNEL_VERSION_TO_ANDROID = {
    "5.10": "12",
    "5.15": "13",
    "6.1":  "14",
    "6.6":  "15",
    "6.12": "16",
}

VARIANT_DISPLAY = {
    "VANILLA":        "Vanilla",
    "RESUKISU":       "ReSukiSU",
    "RESUKISU_SUSFS": "ReSukiSU\\+SUSFS",
    "SUKISU":         "SukiSU\\-Ultra",
    "SUKISU_SUSFS":   "SukiSU\\-Ultra\\+SUSFS",
    "KSUNEXT":        "KernelSU\\-Next",
    "KSUNEXT_SUSFS":  "KernelSU\\-Next\\+SUSFS",
}

# Short-form names for the channel post's Download section — deliberately
# not the same as VARIANT_DISPLAY above (which is still used elsewhere and
# keeps the fuller "+SUSFS"/version-qualified names). No +SUSFS suffix and
# no per-variant version: SuSFS is effectively always-on for the rooted
# variants at this point, so spelling it out on every line just added
# clutter without adding information.
VARIANT_BASE_DISPLAY = {
    "VANILLA":        "Vanilla",
    "RESUKISU":       "ResukiSU",
    "RESUKISU_SUSFS": "ResukiSU",
    "SUKISU":         "SukiSU",
    "SUKISU_SUSFS":   "SukiSU",
    "KSUNEXT":        "KSUNext",
    "KSUNEXT_SUSFS":  "KSUNext",
}

# Single source of truth for addon display names — shared by build_blocks()
# (per-build group caption) and build_channel_caption() (channel post).
# Adding a new addon only means adding an entry here (+ TOGGLE_ADDON_ORDER
# below if it should show as an explicit Enable/Disable line in the group
# caption's Add-ons block).
ADDON_DISPLAY_NAMES = {
    "bbrv3":       "BBRv3",
    "bbg":         "BBG",
    "rekernel":    "Re:Kernel",
    "droidspaces": "Droidspaces",
    "zeromount":   "ZeroMount",
    "nomount":     "NoMount",
    "bore":        "BORE",
    "adios":       "ADIOS",
    "kasumi":      "Kasumi",
    "ntsync":      "NTSync",
    "lz4zstd":     "LZ4+ZSTD",
    "lz4kd":       "LZ4KD",
    "le9uo":       "LE9UO",
    "kcompressd":  "Kcompressd",
    "zram_ir":     "Zram_ir",
}

# Mountless-engine addons are mutually exclusive (only one, or none, active
# per build) and shown as a single "Mountless Engine" line rather than their
# own Enable/Disable row.
MOUNTLESS_ADDON_TOKENS = ("nomount", "zeromount")

# Toggle-style addons shown as explicit Enable/Disable lines in the group
# caption, in display order.
TOGGLE_ADDON_ORDER = ["rekernel", "bbrv3", "bbg", "droidspaces", "bore", "adios", "lz4zstd", "lz4kd", "le9uo", "kasumi", "ntsync", "kcompressd", "zram_ir"]

# Channel-post-only: these four get pulled out of the normal "*Add-ons*"
# bullet list and into their own Telegraph "Features" page instead (see
# build_telegraph_content() and build_channel_caption() below) — they're
# the ones worth a version number, the rest are plain on/off toggles.
# Order here is display order on the Telegraph page.
FEATURE_ADDON_TOKENS = ["bore", "adios", "bbrv3", "bbg"]


def mdv2_escape(s):
    special = r"\_*[]()~`>#+-=|{}.!"
    for ch in special:
        s = s.replace(ch, "\\" + ch)
    return s


def mdv2_escape_url(s):
    s = s.replace("\\", "\\\\")
    s = s.replace(")", "\\)")
    return s


def mdv2_code_escape(s):
    s = s.replace("\\", "\\\\")
    s = s.replace("`", "\\`")
    return s


def utf16_len(s):
    return sum(2 if ord(c) > 0xFFFF else 1 for c in s)


def truncate(caption, limit, suffix="\n\u2026\n```"):
    if utf16_len(caption) <= limit:
        return caption
    suffix_len = utf16_len(suffix)
    result = []
    current_len = 0
    for ch in caption:
        ch_len = 2 if ord(ch) > 0xFFFF else 1
        if current_len + ch_len + suffix_len > limit:
            break
        result.append(ch)
        current_len += ch_len
    return "".join(result) + suffix


def build_blocks(env):
    linux_ver       = mdv2_code_escape(env.get("LINUX_VER", "N/A"))
    build_system    = mdv2_code_escape(env.get("BUILD_SYSTEM_DISPLAY", "N/A"))
    compiler        = mdv2_code_escape(env.get("COMPILER_STRING", "N/A"))
    lto             = mdv2_code_escape(env.get("LTO_MODE", "NONE"))
    kernel_variant  = mdv2_code_escape(env.get("KERNEL_VARIANT_DISPLAY", "N/A"))
    susfs_ver       = mdv2_code_escape(env.get("SUSFS_VER", "N/A"))
    date_str        = mdv2_code_escape(datetime.now().strftime("%d %b %Y"))

    addon_tokens = [t for t in env.get("ADDONS", "").split(",") if t]
    mountless = "N/A"
    for token in addon_tokens:
        if token in MOUNTLESS_ADDON_TOKENS:
            mountless = ADDON_DISPLAY_NAMES.get(token, token)
            break
    mountless = mdv2_code_escape(mountless)

    addon_status_lines = []
    for token in TOGGLE_ADDON_ORDER:
        name = ADDON_DISPLAY_NAMES.get(token, token)
        status = "Enable" if token in addon_tokens else "Disable"
        addon_status_lines.append(f"{name.ljust(16)} : {mdv2_code_escape(status)}")

    commit_short    = env.get("GITHUB_SHA", "")[:7]
    commit_url      = "{}/{}/commit/{}".format(
                        env.get("GITHUB_SERVER_URL", ""),
                        env.get("GITHUB_REPOSITORY", ""),
                        env.get("GITHUB_SHA", ""))
    run_url         = "{}/{}/actions/runs/{}".format(
                        env.get("GITHUB_SERVER_URL", ""),
                        env.get("GITHUB_REPOSITORY", ""),
                        env.get("GITHUB_RUN_ID", ""))
    run_id          = env.get("GITHUB_RUN_ID", "")

    block_saga = (
        "```SAGA\n"
        f"Linux        : {linux_ver}\n"
        f"Build System : {build_system}\n"
        f"Compiler     : {compiler}\n"
        f"LTO          : {lto}\n"
        f"Date         : {date_str}```"
    )
    is_vanilla = env.get("KERNEL_VARIANT", "").upper() == "VANILLA"
    ksu_display = "N/A" if is_vanilla else kernel_variant
    ksu_version = mdv2_code_escape(env.get("KERNEL_VARIANT_VERSION", ""))
    root_lines = [f"KSU     : {ksu_display}"]
    if not is_vanilla and ksu_version:
        root_lines.append(f"Version : {ksu_version}")
    root_lines.append(f"SuSFS   : {susfs_ver}")
    if is_vanilla:
        root_lines.append("Vanilla Build")
    block_root = "```Root-solution\n" + "\n".join(root_lines) + "```"
    block_addons = (
        "```Add-ons\n"
        f"Mountless Engine : {mountless}\n"
        + "\n".join(addon_status_lines) +
        "```"
    )
    footer = "[{}]({}) \\| [Run \\#{}]({})".format(
        mdv2_escape(commit_short),
        mdv2_escape_url(commit_url),
        mdv2_escape(run_id),
        mdv2_escape_url(run_url),
    )

    return block_saga, block_root, block_addons, footer


CHANGELOG_MAX_LEN = 300


def build_push_caption(env):
    """
    Caption for the plain push-event notify (.github/workflows/notify.yml),
    distinct from build_blocks()/build_channel_caption() above (those are
    for release/test build posts). Author is linked to https://t.me/<name> —
    this repo is a solo project, so the git author name and the Telegram
    handle are the same person; no separate mapping needed.
    """
    branch_raw  = env.get("BRANCH", "")
    author      = env.get("AUTHOR", "")
    author_esc  = mdv2_escape(author)
    author_url  = mdv2_escape_url("https://t.me/{}".format(author))

    commit_short = env.get("COMMIT", "")[:7]
    commit_url   = mdv2_escape_url(env.get("URL", ""))

    title = env.get("TITLE", "")
    body  = env.get("BODY", "")

    lines = [
        "New Commit \U0001F4CC",
        "",
        f"Branch : `{mdv2_code_escape(branch_raw)}`",
        f"Author : [{author_esc}]({author_url})",
        "```Tittle\n" + mdv2_code_escape(title) + "```",
    ]
    if body.strip():
        lines.append("```Message\n" + mdv2_code_escape(body) + "```")
    lines.append(f"Commit : [{mdv2_escape(commit_short)}]({commit_url})")

    return truncate("\n".join(lines), PUSH_TEXT_LIMIT)


def build_telegraph_content(env):
    """
    Content for the "Features" Telegraph page, called by telegraph_page.py
    (caption.build_telegraph_content). CONFIG_HZ always shows — it's a
    workflow_dispatch input (TICK_RATE, build.yml), not addon-gated, so
    every build has one regardless of which addons were picked. The rest
    only lists whichever of FEATURE_ADDON_TOKENS were actually enabled
    this run — BORE and ADIOS get their version from bore.sh/adios.sh
    (extracted from the patch filename, see those scripts, threaded
    through telegram.sh's per-variant JSON and channel_post.sh's
    aggregation). BBRv3 has no meaningful version beyond "v3" — the patch
    is fetched by URL per kernel version, nothing in it carries a semver
    — and BBG's setup.sh is pulled live from upstream with nothing to pin
    a version to either, so both are fixed labels rather than resolved
    values.
    """
    addon_tokens = set(t for t in env.get("ADDONS", "").split(",") if t)

    lines = []
    tick_rate = env.get("TICK_RATE", "").strip()
    if tick_rate:
        lines.append(f"CONFIG_HZ: {tick_rate}hz")
    if "bore" in addon_tokens:
        v = env.get("BORE_VERSION", "").strip()
        lines.append(f"BORE - {v}" if v else "BORE")
    if "adios" in addon_tokens:
        v = env.get("ADIOS_VERSION", "").strip()
        lines.append(f"ADIOS - {v}" if v else "ADIOS")
    if "bbrv3" in addon_tokens:
        lines.append("BBR - v3")
    if "bbg" in addon_tokens:
        lines.append("BBG")

    if not lines:
        lines = ["No headline features enabled for this build."]

    return [
        {"tag": "h3", "children": ["SAGA Kernel — Features"]},
        {"tag": "ul", "children": [{"tag": "li", "children": [line]} for line in lines]},
    ]


def build_channel_caption(env, variant_links, variant_versions=None):
    """
    variant_links: dict { "VANILLA": "https://t.me/c/...", "RESUKISU_SUSFS": "...", ... }
    variant_versions: dict { "RESUKISU": "v4.1.0 (35002/2)", "SUKISU_SUSFS": "4.1.2 (40819/2)", ... } —
    optional. Kept as a parameter for signature stability (main() still
    builds and passes it), but no longer rendered: the Download section
    now shows only the short base variant name (see VARIANT_BASE_DISPLAY),
    not a per-variant version, so this isn't read here anymore.
    """
    if variant_versions is None:
        variant_versions = {}
    kernel_ver  = env.get("KERNEL_VERSION", "")
    linux_ver   = env.get("LINUX_VER", "N/A")
    android_ver = KERNEL_VERSION_TO_ANDROID.get(kernel_ver, "?")

    # e.g. "6.1.174" -> "6.1.x"
    major_minor = ".".join(linux_ver.split(".")[:2]) + ".x"

    sections = [
        f"*SAGA \\| Build \\| {mdv2_escape(linux_ver)}*\n"
        f"*GKI Kernel \\| Android {mdv2_escape(android_ver)} \\| Linux {mdv2_escape(major_minor)}*"
    ]

    # Add-ons — only the ones actually enabled for this run. The four
    # FEATURE_ADDON_TOKENS get pulled out into their own Telegraph
    # "Features" link (below) instead of showing up here.
    addon_tokens = [t for t in env.get("ADDONS", "").split(",") if t]
    other_addon_tokens = [t for t in addon_tokens if t not in FEATURE_ADDON_TOKENS]
    # CONFIG_HZ (TICK_RATE) is always set — every build has a tick rate
    # regardless of which addons were picked — so the Features page is
    # always worth linking now, not just when one of FEATURE_ADDON_TOKENS
    # happens to be enabled. Kept both checks rather than relying on
    # bbrv3/bore currently always being in ADDONS (see build.yml) staying
    # that way forever.
    has_feature_content = bool(env.get("TICK_RATE", "").strip()) or any(t in FEATURE_ADDON_TOKENS for t in addon_tokens)

    # Features link — its own section in `sections` so the "\n\n" join
    # below gives it a blank line above and below automatically, same as
    # every other section. Only shown when there's actually a feature
    # addon enabled AND the Telegraph page was created successfully
    # (FEATURES_URL empty means either TELEGRAPH_TOKEN isn't set or the
    # API call failed — telegraph_page.py degrades gracefully either way,
    # so this just quietly omits the line rather than linking nowhere).
    features_url = env.get("FEATURES_URL", "").strip()
    if has_feature_content and features_url:
        sections.append(f"[*Features*]({mdv2_escape_url(features_url)})")

    if other_addon_tokens:
        addon_lines = ["*Add\\-ons*"]
        for token in other_addon_tokens:
            name = ADDON_DISPLAY_NAMES.get(token, token)
            addon_lines.append(f"\\- {mdv2_escape(name)}")
        sections.append("\n".join(addon_lines))

    # Download links — short base name only (see VARIANT_BASE_DISPLAY),
    # no +SUSFS suffix and no per-variant version number.
    download_lines = ["> 📥 *Download*"]

    for variant_key, link in variant_links.items():
        display = VARIANT_BASE_DISPLAY.get(variant_key, mdv2_escape(variant_key))
        safe_link = mdv2_escape_url(link)

        download_lines.append(
            f"> • [{display}]({safe_link})"
        )

    sections.append("\n".join(download_lines))

    # Changelog — manual input, optional, capped so it can't crowd out the
    # rest of the caption if someone pastes something huge. Rendered as a
    # code block, same style as the group caption's Root-solution/Add-ons
    # blocks, instead of plain bold text.
    changelog_raw = env.get("CHANGELOG", "").strip()
    if changelog_raw:
        entries = [e.strip() for e in changelog_raw.split(";") if e.strip()]
        changelog_body = "\n".join(f"- {mdv2_code_escape(entry)}" for entry in entries)
        changelog_block = "```Changelog\n" + changelog_body + "```"
        changelog_block = truncate(changelog_block, CHANGELOG_MAX_LEN)
        sections.append(changelog_block)

    # Traceability — commit + workflow run that produced this post
    commit_short = env.get("GITHUB_SHA", "")[:7]
    commit_url = "{}/{}/commit/{}".format(
        env.get("GITHUB_SERVER_URL", ""),
        env.get("GITHUB_REPOSITORY", ""),
        env.get("GITHUB_SHA", ""))
    commits_url = "{}/{}/commits/main/".format(
        env.get("GITHUB_SERVER_URL", ""),
        env.get("GITHUB_REPOSITORY", ""))
    run_url = "{}/{}/actions/runs/{}".format(
        env.get("GITHUB_SERVER_URL", ""),
        env.get("GITHUB_REPOSITORY", ""),
        env.get("GITHUB_RUN_ID", ""))
    trace_line = "[Commits]({}) \\| [Workflows]({})".format(
        mdv2_escape_url(commits_url), mdv2_escape_url(run_url))
    sections.append(trace_line)

    # Bug reports point to the community discussion group, not the CI group
    group_url = mdv2_escape_url("https://t.me/sagakernel".format(env.get("TELEGRAM_GROUP", "")))
    sections.append(
        f"Found a bug? Let's discuss it in [SAGA CHAT]({group_url})"
    )

    date_str = mdv2_escape(datetime.now().strftime("%-d %b %Y"))
#    donate_url = mdv2_escape_url("https://sociabuzz.com/chainonyourdoor")
#    sections.append(f"{date_str} \u00b7 [Support]({donate_url})")

    sections.append("\\#GKI \\#SAGAKernel")

    caption = "\n\n".join(sections)
    return truncate(caption, CAPTION_LIMIT)



def main():
    # Push-notify mode: `caption.py push <output_file>` — separate from the
    # release/build mode below (2 positional args, no subcommand),
    # since it's a different caller (notify.yml) with a different env-var
    # shape (BRANCH/AUTHOR/COMMIT/URL/TITLE/BODY vs. the build-metadata
    # vars build_blocks()/build_channel_caption() expect).
    if len(sys.argv) == 3 and sys.argv[1] == "push":
        env = os.environ
        caption = build_push_caption(env)
        with open(sys.argv[2], "w") as f:
            f.write(caption)
        print("[info] telegram_caption: push caption written ✅", flush=True)
        return

    out_group   = sys.argv[1]
    out_channel = sys.argv[2]

    env = os.environ

    block_saga, block_root, block_addons, footer = build_blocks(env)

    caption_group = "\n".join([block_saga, block_root, block_addons, footer])
    caption_group = truncate(caption_group, CAPTION_LIMIT)

    # Channel caption — built from VARIANT_LINKS_JSON (provided by channel_post.sh)
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

    caption_channel = build_channel_caption(env, variant_links, variant_versions)

    with open(out_group, "w") as f:
        f.write(caption_group)

    with open(out_channel, "w") as f:
        f.write(caption_channel)

    print("[info] telegram_caption: captions written ✅", flush=True)


if __name__ == "__main__":
    main()
