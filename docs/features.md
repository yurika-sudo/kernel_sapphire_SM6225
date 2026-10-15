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

**Root / hiding**
- KernelSU-Next (built-in SUSFS, `dev-susfs` integration) — see [variants.md](variants.md)
- [Baseband Guard](https://github.com/vc-teahouse/Baseband-guard) (`CONFIG_BBG`)
- NoMount

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

**Install:** requires a module manager (KernelSU-Next or Magisk). Install from the Modules tab — do not flash from recovery.

> [!NOTE]
> One module for the one kernel this repo builds — `seiran-core.zip` is attached to every release.

---

## Droidspaces Support

Full [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) container support is built in — no extra module, no defconfig editing on your side.

Enabled by the build ([pinned release upstream](../sources/source-pins.json) → `droidspaces_tag`):

| Group | Configs |
|---|---|
| Required | `SYSVIPC` · `POSIX_MQUEUE` · `IPC_NS` · `PID_NS` · `DEVTMPFS` · `NETFILTER_XT_MATCH_ADDRTYPE` |
| Networking | `USER_NS` · `IP6_NF_NAT` · `IP6_NF_TARGET_MASQUERADE` · `MACVLAN` (`--net=macvlan`) |
| Firewall in containers | `NETFILTER_XT_TARGET_REJECT` · `_TARGET_LOG` · `NETFILTER_XT_MATCH_RECENT` · `NETFILTER_XT_SET` · full `IP_SET_*` family (UFW / fail2ban) |
| Storage | `OVERLAY_FS` (+ redirect/index/xino/metacopy) · `TMPFS_POSIX_ACL` · `TMPFS_XATTR` (NixOS rootfs) |
| Process limits | `CGROUP_PIDS` (`--pids-limit`) — enabled in [setup-configs.sh](../scripts/setup-configs.sh) |

`SYSVIPC`/`POSIX_MQUEUE` move `struct task_struct`, which would break the KMI — so the build applies upstream's **kABI padding patch** (`ANDROID_KABI_USE` on the reserved slots) before enabling them, and the build **fails** if that patch does not apply. Shipping the configs without the padding is a bootloop, not a warning.

`--cpus` needs `CONFIG_CFS_BANDWIDTH`, which resizes scheduler structs with no padding trick available; it stays off on purpose. Memory limits work — `MEMCG` is already on in GKI.

> [!CAUTION]
> DroidSpaces and SUSFS fight over the same mount table: SUSFS `SUS_MOUNT` / `try_umount` hides and unmounts the bind + overlay mounts a container needs. If a container misbehaves, disable SuSFS (or the SUS_MOUNT feature in the SuSFS manager) before reporting it.

Confirmed working on sapphire — see [community-supported devices](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/community-supported-devices.md).

---

## Patch Inventory

### Stable (`patches/common/`)

Applied to every build. See [`patches/common/`](../patches/common/) for the list, and the file name as the label in the build log.

A local patch that no longer applies is reported at the end of the "Apply patches" step:

```
⚠️  1 local patch(es) did not apply — review before shipping:
     • 0005-zram-read-priority-fix
```

The build continues (the kernel is still bootable), but that feature is missing from the result, so treat it as a to-do, not noise.

### Testing (`patches/testing/`)

Patches under evaluation — only applied when the build is started with `build_type: testing`. See [`patches/testing/`](../patches/testing/).

---

Maintainer config reference: [config-blacklist.md](./config-blacklist.md)
