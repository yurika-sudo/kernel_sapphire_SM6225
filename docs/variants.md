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
| GKI-Compat-Ksun | AOSP LTS (compat) | KernelSU-Next + SUSFS | — |
| GKI-Compat-SukiSU | AOSP LTS (compat) | SukiSU-Ultra + SUSFS | — |
| GKI-Compat-NoKSU | AOSP LTS (compat) | Vanilla | — |

All non-compat variants include: **BBRv1 + Westwood TCP** · **IP_SET** · **Thin LTO** · **Droidspaces support**

---

## Droidspaces Support

This kernel ships with full [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) container support out of the box.

Enabled configs: `SYSVIPC` · `IPC_NS` · `PID_NS` · `POSIX_MQUEUE` · `DEVTMPFS` · Netfilter extras

kABI fix applied for GKI < 6.12 to prevent vendor module crashes on boot.

> **SuSFS users:** disable **"HIDE SUS MOUNTS FOR ALL PROCESSES"** in SuSFS4KSU settings, otherwise containers will fail to start.

Confirmed working on sapphire — see [community-supported devices](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/community-supported-devices.md).

---

## Build Details

| | GKI / GKI-Compat | CLO |
|--|------------------|-----|
| Source | `android.googlesource.com/kernel/common` | `git.codelinaro.org/clo/la/kernel/msm-5.15` |
| Branch | `android13-5.15-lts` | `kernel.lnx.5.15.r1-rel` |
| Config fragment | — | `vendor/bengal_GKI.config` |
| Toolchain | Clang r547379 (topnotchfreaks) | Clang r547379 (topnotchfreaks) |
| LTO | Thin | Thin |
