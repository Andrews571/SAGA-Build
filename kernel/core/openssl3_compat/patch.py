import sys

# certs/extract-cert.c ships with a half-applied backport of the OpenSSL-3
# compat fix: key_pass's declaration is gated behind
# `#ifdef USE_PKCS11_ENGINE`, but nothing in the file ever defines that
# macro, and the PKCS#11 branch further down uses key_pass completely
# unguarded. Result on any OpenSSL 3.x toolchain: key_pass's declaration
# gets compiled out while its usage doesn't, i.e. "use of undeclared
# identifier 'key_pass'".
#
# Fix: define USE_PKCS11_ENGINE whenever the ENGINE API is actually
# available. This is safe for this file specifically because
# ENGINE_load_builtin_engines()/ENGINE_by_id()/etc. a few lines down are
# already called unconditionally (not gated by this macro at all) — so if
# ENGINE support isn't there, this file was already broken before our patch
# touches it.

ANCHOR = "#ifdef USE_PKCS11_ENGINE\nstatic const char *key_pass;\n#endif"

DEFINE_BLOCK = (
    "/* Luminaire: USE_PKCS11_ENGINE is used below to gate key_pass but is\n"
    " * never actually defined upstream in this file (partial OpenSSL-3\n"
    " * backport) -- define it here whenever ENGINE API is available. */\n"
    "#if !defined(OPENSSL_NO_ENGINE) && !defined(OPENSSL_NO_DEPRECATED_3_0)\n"
    "#define USE_PKCS11_ENGINE\n"
    "#endif\n"
)


def main():
    path = sys.argv[1]

    with open(path, "r") as f:
        content = f.read()

    if "#define USE_PKCS11_ENGINE" in content:
        print("[info] openssl3_compat_patch: already patched — skipping", flush=True)
        sys.exit(0)

    if ANCHOR not in content:
        print(
            "[error] openssl3_compat_patch: anchor not found in extract-cert.c — "
            "upstream may have changed this file, check manually!",
            flush=True,
        )
        sys.exit(1)

    content = content.replace(ANCHOR, DEFINE_BLOCK + ANCHOR, 1)

    with open(path, "w") as f:
        f.write(content)

    print("[info] extract-cert.c patched: USE_PKCS11_ENGINE now defined ✅", flush=True)


if __name__ == "__main__":
    main()
