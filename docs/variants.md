# Variants & Features

## Variants

| Variant | Source | Root | Extras |
|---------|--------|------|--------|
| GKI-Ksun | AOSP LTS | KernelSU-Next + SUSFS | BBG |
| GKI-SukiSU | AOSP LTS | SukiSU-Ultra + SUSFS | KPM |
| GKI-NoKSU | AOSP LTS | Vanilla | — |
| CLO-Ksun | CodeLinaro | KernelSU-Next + SUSFS | BBG |
| CLO-SukiSU | CodeLinaro | SukiSU-Ultra + SUSFS | KPM |
| CLO-NoKSU | CodeLinaro | Vanilla | — |
| GKI-Compat-Ksun | AOSP 2023-10 (deprecated) | KernelSU-Next + SUSFS | — |
| GKI-Compat-SukiSU | AOSP 2023-10 (deprecated) | SukiSU-Ultra + SUSFS | — |
| GKI-Compat-NoKSU | AOSP 2023-10 (deprecated) | Vanilla | — |

**Supported Android versions:** GKI / CLO → Android 15+ · GKI-Compat → Android 13 / 14 only

---

## Core Features

**Scheduler**
- [BORE](https://github.com/firelzrd/bore-scheduler) — burst-oriented CFS latency tuning
- CASS — Capacity Aware Superset Scheduler
- prefer_silver — silver-cluster affinity layer on top of CASS
- Battery-oriented tuning: WALT early-migration thresholds, `sched_nr_migrate`, `watermark_scale_factor`, `vm_swappiness`

**Memory**
- MGLRU forced on (`CONFIG_LRU_GEN_ENABLED=y`)
- [le9uo](https://github.com/firelzrd/le9uo) workingset protection
- ZRAM multi-comp support baked into the base config (LZ4 default), with zram-ir tiered compression and huge/idle-page recompression, plus a read-path dispatcher fix

**I/O**
- ADIOS (Adaptive Deadline I/O Scheduler) multi-queue scheduler

**CPU governor**
- [Reflex](https://github.com/firelzrd/reflex) cpufreq governor (backported)

**Network**
- BBRv3 + Westwood TCP congestion control · FQ default qdisc (CAKE / PIE also available)
- ntsync (Wine/Proton sync primitives)

**Security / stability**
- CVE-2026-43499 rtmutex ghostlock UAF fix
- DRM/mi_disp + AVC logspam filtering

**Other**
- Thin LTO
- HZ=300
- Droidspaces support (see below)

---

## Droidspaces Support

This kernel ships with full [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) container support out of the box.

Enabled configs: `SYSVIPC` · `IPC_NS` · `PID_NS` · `POSIX_MQUEUE` · `DEVTMPFS` · Netfilter extras

kABI fix applied for GKI < 6.12 to prevent vendor module crashes on boot.

> **SuSFS users:** Droidspaces isn't compatible with SuSFS. Disable SuSFS before using Droidspaces.

Confirmed working on sapphire — see [community-supported devices](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/community-supported-devices.md).

---

## Build Details

| | GKI | GKI-Compat | CLO |
|--|-----|------------|-----|
| Source | `android.googlesource.com/kernel/common` | `android.googlesource.com/kernel/common` | `git.codelinaro.org/clo/la/kernel/msm-5.15` |
| Branch | `android13-5.15-lts` | `deprecated/android13-5.15-2023-10` | `kernel.lnx.5.15.r1-rel` |
| Config fragment | — | — | `vendor/bengal_GKI.config` |
| Toolchain | Clang r450784e | resolved from `build.config.constants` at build time — likely differs from GKI's, not confirmed | ZyC Clang 14.0.6 |
| LTO | Thin | Thin | Thin |
