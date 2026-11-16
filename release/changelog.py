#!/usr/bin/env python3
"""
Automatic release changelog (T4) — short, user-facing lines, no raw commit spam.

Compares THIS release with the previous release of the same channel
(ptr-stable / ptr-experimental in SAGA-Releases, public saga-release.json) and prints
the lines separated by ';' (the format CHANGELOG already uses in the posts):

  1. manual text from the dispatch input                  (first, untouched)
  2. commit trailers  "Changelog: <text>"  since the previous release commit
  3. Linux version     "Updated Linux 6.1.187 -> 6.1.190"
  4. pins              "Updated ReSukiSU (548d1dd -> 5d6d184)"   (kernel/*/manifest.json diff)
  5. addons            "Added <Addon>" / "Removed <Addon>"        (addon list diff)
  6. toolchain         "Updated toolchain: <old> -> <new>"

Commits WITHOUT a "Changelog:" trailer are ignored on purpose (CI/docs/infra commits are
noise for kernel users). See docs/CHANGELOG-RELEASE.md.

Env: CHANNEL (stable|experimental) or ADDON_PROFILE, RELEASES_REPO, KERNEL_VERSION, ADDONS,
     LINKS_DIR (variant-link JSONs: linux_ver, compiler), MANUAL, GITHUB_SHA, GITHUB_OUTPUT,
     PREV_JSON_FILE (tests/offline: use this file instead of downloading), MAX_ENTRIES (10)
"""
import glob
import json
import os
import re
import subprocess
import sys
import urllib.request

PIN_NAMES = {
    "resukisu": "ReSukiSU",
    "susfs_resukisu": "SuSFS (ReSukiSU)",
    "sukisu": "SukiSU-Ultra",
    "sukisu_builtin": "SukiSU-Ultra (builtin)",
    "susfs_sukisu": "SuSFS (SukiSU)",
    "ksunext": "KernelSU-Next",
    "ksunext_susfs_fork": "KernelSU-Next",
    "susfs_ksunext": "SuSFS (KernelSU-Next)",
}
TRAILER = re.compile(r"^\s*Changelog:\s*(.+?)\s*$", re.IGNORECASE | re.MULTILINE)


def clean(text, limit=120):
    text = re.sub(r"\s+", " ", str(text).replace(";", ",")).strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"


def git(*args, cwd=None):
    try:
        out = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=60)
        return out.stdout if out.returncode == 0 else None
    except Exception:
        return None


def fetch_previous(channel, repo):
    path = os.environ.get("PREV_JSON_FILE", "")
    try:
        if path:
            return json.load(open(path))
        url = f"https://github.com/{repo}/releases/download/ptr-{channel}/saga-release.json"
        with urllib.request.urlopen(url, timeout=20) as r:
            return json.load(r)
    except Exception as e:  # first release of the channel, offline, ...
        print(f"[changelog] no previous release found ({e})", file=sys.stderr)
        return None


def addon_name(token):
    try:
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "telegram"))
        import unified_caption as uc  # registers the CC-profile names too
        return uc.legacy.ADDON_DISPLAY_NAMES.get(token, token)
    except Exception:
        return token


# ---- the pieces ------------------------------------------------------------
def trailer_entries(prev_commit, prev_built_at, cwd=None):
    """'Changelog:' trailers from commits after the previous release."""
    if prev_commit and git("cat-file", "-e", f"{prev_commit}^{{commit}}", cwd=cwd) is not None:
        log = git("log", f"{prev_commit}..HEAD", "--format=%B%x00", cwd=cwd)
    elif prev_built_at:
        log = git("log", f"--since={prev_built_at}", "--format=%B%x00", cwd=cwd)
    else:
        log = None
    entries = []
    for body in (log or "").split("\x00"):
        entries += TRAILER.findall(body)
    return list(reversed(entries))  # oldest first


def pin_entries(prev_commit, manifest_rel, cwd=None):
    if not prev_commit or not manifest_rel:
        return []
    old_txt = git("show", f"{prev_commit}:{manifest_rel}", cwd=cwd)
    try:
        old = json.loads(old_txt) if old_txt else {}
        new = json.load(open(os.path.join(cwd or ".", manifest_rel)))
    except Exception:
        return []
    out = []
    for key, val in new.items():
        a, b = (old.get(key) or {}).get("good", ""), (val or {}).get("good", "")
        if b and a != b:
            out.append(f"Updated {PIN_NAMES.get(key, key)} ({a[:7] or 'new'} → {b[:7]})")
    return out


def addon_entries(prev_addons, cur_addons):
    if not prev_addons:
        return []
    out = [f"Added {addon_name(t)}" for t in cur_addons if t not in prev_addons]
    out += [f"Removed {addon_name(t)}" for t in prev_addons if t not in cur_addons]
    return out


def read_links(links_dir):
    linux, compiler = "", ""
    for f in sorted(glob.glob(os.path.join(links_dir, "*.json"))) if links_dir else []:
        try:
            d = json.load(open(f))
            linux = linux or d.get("linux_ver", "")
            compiler = compiler or d.get("compiler", "")
        except Exception:
            pass
    return linux, compiler


def main():
    env = os.environ
    channel = env.get("CHANNEL") or ("experimental" if env.get("ADDON_PROFILE") == "CC_Addons" else "stable")
    repo = env.get("RELEASES_REPO", "Andrews571/SAGA-Releases")
    cwd = env.get("REPO_DIR") or None
    kv = env.get("KERNEL_VERSION", "6.1")
    max_entries = int(env.get("MAX_ENTRIES", "10"))

    entries = [e.strip() for e in env.get("MANUAL", "").split(";") if e.strip()]
    prev = fetch_previous(channel, repo)
    cur_linux, cur_compiler = read_links(env.get("LINKS_DIR", ""))
    cur_addons = [t for t in env.get("ADDONS", "").split(",") if t]

    if prev:
        k = prev.get("kernel", {})
        pc, pb = k.get("commit", ""), k.get("built_at", "")
        entries += trailer_entries(pc, pb, cwd)
        if cur_linux and k.get("version") and cur_linux != k["version"]:
            entries.append(f"Updated Linux {k['version']} → {cur_linux}")
        manifests = glob.glob(os.path.join(cwd or ".", "kernel", f"android*-{kv}-lts", "manifest.json"))
        if manifests:
            entries += pin_entries(pc, os.path.relpath(manifests[0], cwd or "."), cwd)
        entries += addon_entries(prev.get("addons", []), cur_addons)
        old_cc = (prev.get("toolchain") or {}).get("compiler", "")
        if old_cc and cur_compiler and old_cc != cur_compiler:
            entries.append(f"Updated toolchain: {old_cc} → {cur_compiler}")

    seen, out = set(), []
    for e in map(clean, entries):
        if e and e not in seen:
            seen.add(e)
            out.append(e)
    if len(out) > max_entries:
        extra = len(out) - (max_entries - 1)
        out = out[: max_entries - 1] + [f"+{extra} more changes"]

    text = ";".join(out)
    print(text)
    if env.get("GITHUB_OUTPUT"):
        with open(env["GITHUB_OUTPUT"], "a") as f:
            f.write(f"text={text}\n")


if __name__ == "__main__":
    main()
