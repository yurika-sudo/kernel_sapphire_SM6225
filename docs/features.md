# Features

## Core Features

**Scheduler**
- [BORE](https://github.com/firelzrd/bore-scheduler) — burst-oriented CFS latency tuning
- CASS — Capacity Aware Superset Scheduler
- prefer_silver — silver-cluster affinity layer on top of CASS
- [NAP](https://github.com/firelzrd/nap) — cpuidle governor (fixedpoint steambot12)
- Battery-oriented tuning: WALT early-migration thresholds, `sched_nr_migrate`, `watermark_scale_factor`, `vm_swappiness`, yield ratelimit, LIFO wait accept

**Memory**
- MGLRU forced on (`CONFIG_LRU_GEN_ENABLED=y`)
- [le9uo](https://github.com/firelzrd/le9uo) workingset protection
- ZRAM multi-comp + zram-ir tiered recompression with huge/idle-page recompression — requires [Seiran Core](#seiran-core-module)
- zstd upgraded to v1.5.7

**I/O**
- ADIOS (Adaptive Deadline I/O Scheduler) multi-queue scheduler

**CPU governor**
- [Reflex](https://github.com/firelzrd/reflex) cpufreq governor (backported)

**Network**
- BBRv3 + Westwood TCP congestion control · FQ default qdisc (CAKE / PIE also available)
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

Stable patches applied to all variants (GKI, GKI-Legacy). See [`patches/common/`](../patches/common/) for the full list.

### GKI-Legacy only (`patches/gki-legacy-only/`)

Compatibility shims for the GKI-Legacy tree (pinned to 5.15.123, deprecated/android13-5.15-2023-10).
For gki-legacy the patches/gki-legacy-only/ variant is used INSTEAD of the common patch of the same name when it exists; if no legacy-only variant exists the common patch is tried and, if it does not apply on 5.15.123, it is reported as needing manual review and skipped (build continues).

Verified state against 5.15.123 (sequential baseline, --fuzz=0)
-------------------------------------------------------------
- 70 of 92 patches/common patches apply cleanly (deprecated/android13-5.15-2023-10).
- Patches that do not apply on 5.15.123 have a regenerated variant in patches/gki-legacy-only/ used INSTEAD of the common patch; the remaining ones are reported as needing manual review and skipped. See patches/gki-legacy-only/README.md for the current list.
- The rest are either covered by a legacy variant or reported as needing manual review and skipped.
  - binder-get-node-fastpath-6.12-5.15.patch: new binder API path
  - schedutil-rate-limit-latency-6.12-5.15.patch: new scheduler API: ignore_rate_limit_latency_sensitive
  - prefer_silver_pelt_only.patch: new Kconfig: CONFIG_SCHED_PREFER_SILVER
  - rcu-lazy-flush-3s-module-param.patch: missing LAZY_FLUSH_JIFFIES define
  - sis-util-llc-idle-scan-5.15-sapphire.patch: new topology helpers
  - bore-5.15-sapphire.patch: new Kconfig: CONFIG_SCHED_BORE
  - blk-adios-backport.patch: new files required: block/adios.c and friends
  - eevdf-backport-sched.patch: scheduler core divergence on 5.15.123
  - sched-cambyses-v0.7.0-5.15.patch: scheduler core divergence on 5.15.123
  - zstd-upgrade-v157.patch: new zstd API: zstd_dstream and friends
  - bbrv3-5.15-sapphire.patch: TCP struct divergence on 5.15.123
  - 0002-logspam-filter-nfc-hwsvc.patch: printk filter hook not present on 5.15.123
  - 0003-logspam-filter-n7-wlan-hdd.patch: printk filter hook not present on 5.15.123
  - 0004-logspam-filter-cmn-mlme.patch: printk filter hook not present on 5.15.123
- 4 common patches are not applicable on 5.15.123 at all:
  - qcom-logbuf-print-caller-arity-fix.patch: target file drivers/soc/qcom/qcom_logbuf_boot_log.c does not exist
  - walt-early-migrate-battery.patch: target file kernel/sched/walt/sysctl.c does not exist (no WALT scheduler)
  - cfs-bandwidth-kabi-safe-gki-5.15-sapphire.patch: already covered by the earlier cass patch, skipped as applied
  - zstd-upgrade-v157.patch: new zstd API; also target files absent on 5.15.123

GKI-Legacy variant resolution:
- Verified legacy-only variant: `rcu-hurry-migration-net-5.15.patch`
- kernel-release-spoof: regenerated for the AIO tree (5.15.225); its legacy variant is still pending on 5.15.123 (proc osrelease spoof in kernel/utsname_sysctl.c differs structurally)

### Testing (`patches/testing/`)

Patches under evaluation — may be unstable or variant-specific. See [`patches/testing/`](../patches/testing/).

---

Maintainer config reference: [config-blacklist.md](./config-blacklist.md)
