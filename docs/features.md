# Features

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

**Security / stability**
- CVE-2026-43499 rtmutex ghostlock UAF fix
- CVE-2026-64560 posix CPU timers UAF fix
- DRM/mi_disp + AVC logspam filtering

**Other**
- Thin LTO
- HZ=300
- Droidspaces support (see below)
- ntsync (Wine/Proton sync primitives)
- arm64 memcmp optimization for Snapdragon 685

---

## ZRAM Multi-Comp Module

The kernel ships zram-ir/multi-comp support baked in, but `CONFIG_ZRAM=m` means `zram.ko`/`zsmalloc.ko` build as loadable modules — they don't reach the device via the AK3 kernel-image ZIP alone. A separate KSU/Magisk module carries them.

> [!WARNING]
> **Kernel ZIP alone = no ZRAM at all**, on every variant. This isn't "multi-comp missing" — `zram0` doesn't come up at all until this module loads `zram.ko`/`zsmalloc.ko` for you. Flashing just the kernel and expecting ZRAM/swap to work is the single most common source of "why is my RAM management worse than before" reports.

**What it does:** loads `zram.ko` + `zsmalloc.ko` with multi-comp + zram-ir tiered recompression at `post-fs-data`.

**Get it — 2 ways:**
- **GitHub Release:** attached as `zram-multicomp-<variant>.zip` alongside the kernel ZIP.
- **Telegram:** sent automatically to the same channel as build/manager updates — [t.me/tmplogchat](https://t.me/tmplogchat).

**Requires a module manager** — it's a KSU/Magisk module, installed through the manager app, not flashed from recovery.
- **GKI-Ksun/SukiSU or CLO-Ksun/SukiSU:** you already need the matching manager APK for root (see [Manager](./installation.md#manager)) — install the zram module the same way.
- **NoKSU:** the kernel has no root/manager baked in. Root separately first — Magisk (patch `boot.img`) or a boot.img-patched KSU-Next/SukiSU-Ultra — then install this module from that manager's Modules tab.

> [!NOTE]
> Must match your flashed variant exactly (e.g. `zram-multicomp-gki-ksun.zip` for GKI-KSU-Next). Wrong variant safely no-ops — the module just won't load, no harm — but you also won't get multi-comp/zram-ir. Check status via the module's **Action** button after install.

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

Applied to all variants (GKI, CLO, GKI-Compat).

| Patch | Description |
|---|---|
| `bore-5.15-sapphire` | BORE burst-oriented scheduler |
| `adios-backport` | ADIOS multi-queue I/O scheduler |
| `reflex-gki-5.15` | Reflex cpufreq governor |
| `bbrv3-5.15-sapphire` | BBRv3 TCP congestion control |
| `prefer_silver_pelt_only` | Silver-cluster affinity tuning |
| `walt-early-migrate-battery` | WALT early migration threshold |
| `sched-nr-migrate-battery` | `sched_nr_migrate` battery tuning |
| `watermark_scale_factor` | VM watermark tuning |
| `vm_swappiness` | Default swappiness tuning |
| `le9uo-workingset-protection-5.15-sapphire` | le9uo working set protection |
| `0001-zram-multi-comp-recompress-huge-idle-5.15` | ZRAM multi-comp + huge/idle recompression |
| `0002-zram-ir-1.2-5.15` | zram-ir tiered compression |
| `0003-zram-read-path-dispatcher-fix` | ZRAM read path dispatcher fix |
| `0004-zram-ir-prio-underflow-fix` | zram-ir priority underflow fix |
| `0005-zram-read-priority-fix` | ZRAM read priority fix |
| `0006-zram-ir-fallback-null-guard` | zram-ir NULL guard for flush requests |
| `arm64-memcmp-optimize-sapphire` | arm64 memcmp optimization |
| `logspam-filter-drm-mi_disp-avc` | DRM/mi_disp + AVC log suppression |
| `0001-logspam-filter-nfc-hwsvc` | NFC hwsvc log suppression |
| `0002-logspam-filter-n7-wlan-hdd` | WLAN HDD log suppression |
| `0003-logspam-filter-cmn-mlme` | CMN MLME log suppression |
| `qcom-logbuf-print-caller-arity-fix` | Qcom logbuf print caller arity fix |
| `cve-2026-64560-posix-cpu-timers-uaf` | CVE-2026-64560 posix CPU timers UAF fix |
| `rtmutex-ghostlock-cve-2026-43499-uaf-fix` | CVE-2026-43499 rtmutex ghostlock UAF fix |

### GKI-Compat only (`patches/gki-compat-only/`)

Compatibility shims applied on top of `patches/common/` for the GKI-Compat tree (pinned to 5.15.123).

| Patch | Description |
|---|---|
| `0001-vma-pad-start-compat-shim` | VMA pad-start compat shim |
| `0002-adios-cleanup-guard-compat` | ADIOS cleanup guard for older tree |
| `0003-posix-cpu-timers-rcu-guard-compat` | RCU guard macro compat shim for CVE-2026-64560 |

### Under Testing (`patches/testing/`)

> [!WARNING]
> Patches in this section are not yet promoted to stable. They may be incomplete, unstable, or pending boot verification. Flash at your own risk — stick to a stable release if you're unsure.

| Patch | Description |
|---|---|
| `cass-5.15-sapphire-updated` | CASS scheduler |
| `0001-cpuidle-nap-governor-arm64-scalar-gki` | cpuidle NAP governor (arm64 scalar) |
| `kcompressd-sapphire-page-based` | kcompressd async compression daemon (page-based backport) |
| `mglru-enable-walks-mmu` | MGLRU MMU notifier walks enable |

---

Maintainer config reference: [config-blacklist.md](./config-blacklist.md)
