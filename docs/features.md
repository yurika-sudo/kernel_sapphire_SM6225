# Features

## Core Features

**Scheduler**
- [BORE](https://github.com/firelzrd/bore-scheduler) — burst-oriented CFS latency tuning
- CASS — Capacity Aware Superset Scheduler
- prefer_silver — silver-cluster affinity layer on top of CASS
- [NAP](https://github.com/firelzrd/nap) — cpuidle governor (fixedpoint steambot12)
- Battery-oriented tuning: WALT early-migration thresholds, `sched_nr_migrate`, `watermark_scale_factor`, `vm_swappiness`, yield ratelimit, LIFO wait accept
- The Cambyses CFS load balancer is included in the GKI-Legacy 5.15.123 patch set.

**Memory**
- MGLRU forced on (`CONFIG_LRU_GEN_ENABLED=y`)
- [le9uo](https://github.com/firelzrd/le9uo) workingset protection
- ZRAM multi-comp + zram-ir tiered recompression with huge/idle-page recompression — requires [Seiran Core](#seiran-core-module)
- zstd upgraded to v1.5.7

**I/O**
- ADIOS (Adaptive Deadline I/O Scheduler) multi-queue scheduler

**CPU governor**
- [Reflex](https://github.com/firelzrd/reflex) cpufreq governor (backported)
- GKI-Legacy schedutil bypasses its rate limit for DL, RT, iowait, and latency-sensitive or boosted tasks.

**Network**
- BBRv3 + Westwood TCP congestion control · FQ default qdisc (CAKE / PIE also available)
- GKI-Legacy 5.15.123 includes the BBRv3 TCP congestion-control backport with the legacy PLB and sysctl adaptation.
- TCP write buffer increased to 16MB

**Security / stability**
- CVE-2026-43499 rtmutex ghostlock UAF fix
- CVE-2026-64560 posix CPU timers UAF fix

**Other**
- Thin LTO
- HZ=300
- kbuild modpost/kallsyms speedup
- ntsync (Wine/Proton sync primitives)
- arm64 memcmp optimization for Snapdragon 685
- timer slack reduced to 50ns
- DRM/mi_disp, NFC, WLAN HDD, CMN MLME logspam filtering
- GKI-Legacy filters `android.hardware.nfc@1.2` logspam through the existing printk filter.
- GKI-Legacy uses a Binder empty-tree lookup fast path and a single-lock poll work check.
- Droidspaces support (see below)

---


## Seiran Core Module

> [!CAUTION]
> **Required — no exceptions.** Without this module, ZRAM will not work at all — `zram0` won't come up, swap won't run, and RAM management will be worse than stock.

The kernel ZIP alone is not enough. `CONFIG_ZRAM=m` means `zram.ko`/`zsmalloc.ko` are loadable modules, not baked into the kernel image. Seiran Core is the KSU/Magisk module that loads them.

**What it does:** loads `zram.ko` + `zsmalloc.ko` with multi-comp + zram-ir tiered recompression, then sets NAP as cpuidle governor, ADIOS as I/O scheduler, and Reflex as cpufreq governor — all at `post-fs-data`.

**Download:**
- **GitHub Release:** `seiran-core.zip` attached alongside the kernel ZIP.
- **Telegram:** [t.me/tmplogchat](https://t.me/tmplogchat)

**Install:** requires a module manager (KSU/Magisk). Install from the Modules tab — do not flash from recovery.
- **NoKSU:** root first via Magisk or KSU-Next/SukiSU-Ultra, then install from there.

> [!NOTE]
> Universal — works across all variants (GKI × KSU-Next/SukiSU-Ultra/NoKSU).

---

## Droidspaces Support

This kernel ships with full [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) container support out of the box.

Enabled configs: `SYSVIPC` · `IPC_NS` · `PID_NS` · `POSIX_MQUEUE` · `DEVTMPFS` · Netfilter extras

kABI fix applied for GKI < 6.12 to prevent vendor module crashes on boot.

> [!CAUTION]
> Droidspaces isn't compatible with SuSFS. Disable SuSFS before using Droidspaces.

Confirmed working on sapphire — see [community-supported devices](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/community-supported-devices.md).

---

## Patch Inventory

### Stable (`patches/common/`)

Stable patches for the GKI (AIO) variant. See [`patches/common/`](../patches/common/) for the full list.

### GKI-Legacy (`patches/gki-legacy/`)

Legacy uses its own patch set in `patches/gki-legacy/` (one file per common patch, applied INSTEAD of `patches/common/` for gki-legacy). The GKI-Legacy tree is pinned to kernel 5.15.123. See `patches/gki-legacy/PENDING.txt` for the not-ported list and the reason per patch. Patches that cannot apply on 5.15.123 as-is are listed as pending; those that have a rebuilt variant for 5.15.123 live in `patches/gki-legacy-overrides/`, including the CVE-2026-64560 posix-cpu-timers UAF fix and the ABI-safe CFS bandwidth patch. The legacy set now includes the ABI-safe CFS bandwidth patch, so `CONFIG_CFS_BANDWIDTH` and `CONFIG_FAIR_GROUP_SCHED` remain enabled on 5.15.123 without changing the frozen `task_group` ABI. KSU-Next and SukiSU-Ultra integrations verified on the legacy tree: driver linked, SUSFS applies. The legacy set now includes a release-spoof override that reports 6.12.25 for non-bypassed callers, so the existing LINUX_VERSION_CODE pin must be made legacy-aware or skipped for this real 5.15.123 tree.

- Patches in the legacy set apply cleanly on 5.15.123
- Common patches are pending (not yet ported to 5.15.123; see `patches/gki-legacy/PENDING.txt`)

### Testing (`patches/testing/`)

Patches under evaluation — may be unstable or variant-specific. See [`patches/testing/`](../patches/testing/).

---

Maintainer config reference: [config-blacklist.md](./config-blacklist.md)
