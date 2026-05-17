#!/usr/bin/env python3
"""
Apply SUSFS changes to KernelSU-Next source programmatically.
This replaces the fragile patch file approach.
"""

import re
import sys
import os

KSU_DIR = sys.argv[1] if len(sys.argv) > 1 else "."

def read(path):
    with open(os.path.join(KSU_DIR, path)) as f:
        return f.read()

def write(path, content):
    with open(os.path.join(KSU_DIR, path), 'w') as f:
        f.write(content)

def apply(path, old, new, required=True):
    content = read(path)
    if old in content:
        write(path, content.replace(old, new, 1))
        print(f"[OK] {path}")
        return True
    else:
        if required:
            print(f"[WARN] {path}: pattern not found, may already applied")
        return False

# ======================================================
# kernel/Kconfig — add SUSFS config options
# ======================================================
apply("kernel/Kconfig",
    'config KSU_DEBUG\n\tbool "KernelSU debug mode"',
    '''config KSU_SUSFS
\tbool "Enable SUSFS"
\tdefault y
\thelp
\t  Enable SUSFS support for KernelSU.

config KSU_SUSFS_SUS_PATH
\tbool "Enable SUS path"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_SUSFS_SUS_MOUNT
\tbool "Enable SUS mount"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_SUSFS_SUS_KSTAT
\tbool "Enable SUS kstat"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_SUSFS_SPOOF_UNAME
\tbool "Enable spoof uname"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_SUSFS_ENABLE_LOG
\tbool "Enable SUSFS log"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
\tbool "Hide KSU SUSFS symbols"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
\tbool "Spoof cmdline or bootconfig"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_SUSFS_OPEN_REDIRECT
\tbool "Enable open redirect"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_SUSFS_SUS_MAP
\tbool "Enable SUS map"
\tdepends on KSU_SUSFS
\tdefault y

config KSU_DEBUG
\tbool "KernelSU debug mode"''',
    required=False
)

# ======================================================
# kernel/core/init.c — add susfs_init + fix includes
# ======================================================
content = read("kernel/core/init.c")

# Add setuid_hook and sucompat includes
for old_inc, new_inc in [
    ('#include "hook/syscall_hook_manager.h"\n', ''),
    ('#include "hook/syscall_hook.h"\n', '#include "hook/setuid_hook.h"\n#include "feature/sucompat.h"\n'),
    ('#include "feature/selinux_hide.h"\n', ''),
    ('#include "hook/lsm_hook.h"\n', ''),
]:
    content = content.replace(old_inc, new_inc)

# Remove x86 INDIRECT_SAFE compile error block
content = re.sub(
    r'#if defined\(__x86_64__\)\n#include <asm/cpufeature\.h>.*?#endif\n\n',
    '', content, flags=re.DOTALL, count=1
)

# Remove ksu_late_loaded global
content = content.replace('bool ksu_late_loaded;\n\n', '')

# Remove x86 runtime safety check in kernelsu_init
content = re.sub(
    r'#if defined\(__x86_64__\)\n    // If the kernel has.*?#endif\n\n',
    '', content, flags=re.DOTALL, count=1
)

# Remove ksu_late_loaded assignment
content = re.sub(
    r'#ifdef MODULE\n\tksu_late_loaded = \(current->pid != 1\);\n#else\n\tksu_late_loaded = false;\n#endif\n\n',
    '', content, count=1
)

# Add susfs_init before prepare_creds
SUSFS_INIT = '#ifdef CONFIG_KSU_SUSFS\n    susfs_init();\n#endif\n\n'
if 'susfs_init()' not in content:
    content = content.replace(
        '    ksu_cred = prepare_creds();',
        SUSFS_INIT + '    ksu_cred = prepare_creds();',
        1
    )

# Remove syscall_hook_init
content = content.replace('\n\tksu_syscall_hook_init();\n', '\n')

# Add sucompat_init and setuid_hook_init after feature_init
if 'ksu_sucompat_init' not in content:
    content = content.replace(
        '\tksu_feature_init();\n',
        '\tksu_feature_init();\n\n    ksu_sucompat_init();\n\n\tksu_setuid_hook_init();\n'
    )

# Remove lsm_hook and selinux_hide inits
content = content.replace('\n\tksu_lsm_hook_init();\n', '\n')
content = content.replace('\n\tksu_selinux_hide_init();\n', '\n')

# Simplify late_loaded branch if still present
if 'ksu_late_loaded' in content:
    old_block = re.search(
        r'\tif \(ksu_late_loaded\) \{.*?\} else \{.*?\}\n',
        content, re.DOTALL
    )
    if old_block:
        simple_block = (
            '\tksu_allowlist_init();\n\n'
            '\tksu_throne_tracker_init();\n\n'
            '\tksu_ksud_init();\n\n'
            '\tksu_file_wrapper_init();\n'
        )
        content = content[:old_block.start()] + simple_block + content[old_block.end():]

# Remove MODULE/kobject_del block
content = re.sub(
    r'#ifdef MODULE\n#ifndef CONFIG_KSU_DEBUG\n\tkobject_del.*?#endif\n#endif\n',
    '', content, flags=re.DOTALL
)

# Fix exit function
content = content.replace(
    '\t// Phase 1: Stop all hooks first to prevent new callbacks\n\tksu_syscall_hook_manager_exit();\n\n',
    ''
)
content = re.sub(
    r'\tif \(!ksu_late_loaded\)\n\t\tksu_ksud_exit\(\);\n',
    '\tksu_ksud_exit();\n',
    content
)
content = content.replace('\t// Phase 2: Now safe to release data structures\n', '\t// Now safe to release data structures\n')
content = content.replace('\n\tksu_selinux_hide_exit();\n', '')
content = content.replace('\n\tksu_lsm_hook_exit();\n', '')

write("kernel/core/init.c", content)
print("[OK] kernel/core/init.c")

# ======================================================
# kernel/policy/allowlist.c — remove manager/webview checks
# ======================================================
content = read("kernel/policy/allowlist.c")
# Remove manager appid check block
pattern_manager = re.compile(
    r'	+if \(likely\(ksu_is_manager_appid_valid\(\)\).*?return false;
	+\}
',
    re.DOTALL
)
# Remove webview zygote check block
pattern_webview = re.compile(
    r'	+if \(unlikely\(uid == WEBVIEW_ZYGOTE_UID\)\).*?return false;
	+\}
',
    re.DOTALL
)
changed = False
if pattern_manager.search(content):
    content = pattern_manager.sub('', content, count=1)
    changed = True
if pattern_webview.search(content):
    content = pattern_webview.sub('', content, count=1)
    changed = True
if changed:
    write("kernel/policy/allowlist.c", content)
    print("[OK] kernel/policy/allowlist.c")
else:
    print("[WARN] kernel/policy/allowlist.c: patterns not found")

# ======================================================
# kernel/policy/app_profile.c — remove tp_marker include
# ======================================================
apply("kernel/policy/app_profile.c",
    '#include "hook/tp_marker.h"\n', '')

print("\n[DONE] All SUSFS changes applied to KernelSU-Next")
