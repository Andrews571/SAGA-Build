<div align="center">

<img src="https://raw.githubusercontent.com/primer/octicons/main/icons/cpu-24.svg" width="64" height="64" />

# SAGA KERNEL

[![Build](https://img.shields.io/github/actions/workflow/status/Andrews571/SAGA-Build/build.yml?branch=main&label=build&logo=github&style=for-the-badge)](https://github.com/Andrews571/SAGA-Build/actions)
[![Telegram](https://img.shields.io/badge/Telegram-SAGA-blue?style=for-the-badge&logo=telegram)](https://t.me/c/4443561826/1)
[![Lint](https://img.shields.io/github/actions/workflow/status/Andrews571/SAGA-Build/lint.yml?branch=main&label=lint&logo=githubactions&style=for-the-badge)](https://github.com/Andrews571/SAGA-Build/actions/workflows/lint.yml)
[![Kernel](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgithub.com%2FAndrews571%2FSAGA-Releases%2Freleases%2Fdownload%2Fptr-stable%2Fsaga-release.json&query=%24.kernel.version&label=kernel&color=informational&style=for-the-badge&logo=android)](https://github.com/Andrews571/SAGA-Releases/releases)
[![Stable](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgithub.com%2FAndrews571%2FSAGA-Releases%2Freleases%2Fdownload%2Fptr-stable%2Fsaga-release.json&query=%24.kernel.run&label=stable&color=success&style=for-the-badge&logo=android&prefix=R)](https://github.com/Andrews571/SAGA-Releases/releases)
[![Experimental](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fgithub.com%2FAndrews571%2FSAGA-Releases%2Freleases%2Fdownload%2Fptr-experimental%2Fsaga-release.json&query=%24.kernel.run&label=experimental&color=orange&style=for-the-badge&logo=android&prefix=R)](https://github.com/Andrews571/SAGA-Releases/releases)
[![Download](https://img.shields.io/badge/download-SAGA--Releases-success?style=for-the-badge&logo=github)](https://github.com/Andrews571/SAGA-Releases/releases)
[![License](https://img.shields.io/badge/license-GLWTS-lightgrey?style=for-the-badge)](LICENSE)
</div>

---

## 📖 What is this?

**SAGA** is a build orchestration repository for the **SAGA** Android GKI kernel.
This repo does **not** contain kernel source — it contains all the scripts and GitHub Actions workflows that:

1. Download the kernel source from `Saga-kernel`
2. Apply patches, integrations, and addons
3. Build the kernel via **MAKE**
4. Package and release via AnyKernel3 + Telegram

---

## 📦 Download

Kernels are published to **[SAGA-Releases](https://github.com/Andrews571/SAGA-Releases/releases)** (and to the Telegram channel) in two channels:

| Channel | Addon profile | Pointer |
|---|---|---|
| **stable** | `Default_Addons` (ADIOS) | `ptr-stable` |
| **experimental** | `CC_Addons` (ADIOS-Clutch + CC Governor + BORE-WARP + Clutch-Signals) | `ptr-experimental` |

Each release ships one AnyKernel3 zip per variant. The badges above show the kernel version and build number currently on each channel.

---

## 🧩 Variants and supported kernels

| Variant | What it is |
|---|---|
| `VANILLA` | Kernel + addons, no root solution |
| `RESUKISU` | [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) (+ SuSFS) |
| `SUKISU` | [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) (+ SuSFS) |
| `KSUNEXT` | [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) (+ SuSFS) |

| Kernel | Android | Status |
|---|---|---|
| **6.1** | android14 | ✅ supported |
| 5.10 / 5.15 / 6.6 / 6.12 | android12 / 13 / 15 / 16 | not available yet (no patch folder in this repo) |

Build options: Clang toolchain (**AOSP**, **Neutron**, **WeebX**, **ZyC**, **Greenforce**) + ccache-ECS, LTO `NONE` / `THIN` / `FULL`, tick rate 100 / 250 / 500 / 1000 Hz.

---

## 🧰 Addons

Always on: `bbrv3`, `bbg`, `bore`, `ntsync`, `util-avg-fix`, `unicode-fix`, `pm-wakelock-blocker`, `droidspaces`, `lz4zstd`, `lz4kd`, plus the profile addons (`adios`, or `adios-clutch` + `cc-governor` + `bore-warp` + `clutch-signals`).
Toggles: `le9uo` and `kcompressd` (on by default), `zram-ir`, `rekernel`, `kasumi`, `mglru` (off by default), and one mountless engine (`nomount` or `zeromount`).

The full list with origin, license and upstream tracking is in **[docs/ADDONS-LISTA.md](docs/ADDONS-LISTA.md)**.

---

## 🚀 Running a build

**Actions → ⚔️ SAGA-Builder → Run workflow**, then pick:

| Input | Options |
|---|---|
| **Run Mode** | `Dry Run` (no compile, validates the flow) · `Warm Run` (compiles only to warm the ccache/LTO caches; the Pin Scout uses it to test new pins) · `Build` (real build, posts to the test thread) · `Release` (real build + publish to SAGA-Releases and the Telegram release thread) |
| **Build System** | `Make - AOSP` / `Neutron` / `WeebX` / `Zyc` / `Greenforce` |
| **Kernel Version / Source** | `6.1` · `live` / `live-staging` / `mirror` / `ramabondanp` |
| **Variants** | `Vanilla`, `ReSukiSU`, `SukiSU-Ultra`, `KernelSU-Next` (toggle each), `SuSFS` enable/disable |
| **Addon Profile** | `Default_Addons` or `CC_Addons` (decides the release channel) |
| **Extras** | Mountless engine, tick rate, LTO mode, addon toggles, changelog text, `Update Arsenal` |

The **Pin Scout** runs every 6 hours and keeps the root-solution and SuSFS pins up to date on its own (see [docs/PIN-SCOUT.md](docs/PIN-SCOUT.md)). Leave `test_candidates` off when running by hand.

---

## 📚 Docs

- [Arquitetura](docs/ARQUITETURA.md) · [Como adicionar um addon](docs/ADDONS.md) · [Lista de addons](docs/ADDONS-LISTA.md) · [Pin Scout](docs/PIN-SCOUT.md) · [Pins verificados](docs/PINS.md) · [Changelog de manutenção](docs/CHANGELOG-MANUTENCAO.md)

---

##  Credits

- [ccache-ECS](https://github.com/cctv18/ccache-ECS) — cctv18
- [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) — ReSukiSU Team
- [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) — SukiSU Team
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) — KernelSU-Next Team
- [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) — simonpunk
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3) — osm0sis
- [Baseband Guard](https://github.com/vc-teahouse/Baseband-guard) — vc-teahouse
- [BBRv3 backport](https://github.com/WildKernels/kernel_patches/tree/main/common/bbrv3) — fatalcoder524
- [ZeroMount](https://github.com/Enginex0/zeromount) — Enginex0
- [NoMount](https://github.com/maxsteeel/nomount) — maxsteeel
- [Re:Kernel](https://github.com/Sakion-Team/Re-Kernel) — Sakion-Team
- [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) — ravindu644
- [BORE Scheduler](https://github.com/firelzrd/bore-scheduler) — firelzrd
- [ADIOS](https://github.com/firelzrd/adios) — firelzrd
- [NTSync](https://github.com/WildKernels/kernel_patches/tree/main/common/ntsync) — driver by Elizabeth Figura (CodeWeavers), GKI backport by luigimak & fatalcoder524
- [AOSP Clang mirror](https://github.com/bachnxuan/aosp_clang_mirror) — bachnxuan
- [Greenforce Clang](https://github.com/greenforce-project/greenforce_clang) — greenforce-project
- [Neutron Clang](https://github.com/Neutron-Toolchains/clang-build-catalogue) — Neutron-Toolchains
- [WeebX Clang](https://github.com/XSans0/WeebX-Clang) — XSans0
- [ZyC Clang](https://github.com/ZyCromerZ/Clang) — ZyCromerZ

---
- thanks for all!
