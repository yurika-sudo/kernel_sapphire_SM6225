# Seiran Kernel

Automated kernel builder for **Redmi Note 13 4G/NFC (sapphire/sapphiren)** — `android13-5.15` GKI.

> Flash at your own risk. Built and tested on sapphire/sapphiren only.
> Support for other devices? Hit me up on [Telegram](https://t.me/home_yu_chat). You take full responsibility — bootloop/brick ain't on me.

---

## Variants

| Variant | Root | Extras |
|---------|------|--------|
| GKI-Wild | Wild-KSU + SUSFS | BBG |
| GKI-SukiSU | SukiSU-Ultra + SUSFS | KPM |
| GKI-NoKSU | Vanilla | — |

All variants include: **BBRv1 + Westwood TCP** · **IP_SET** · **Thin LTO** · **Droidspaces support**

> Wild-KSU supports both Wild and KernelSU-Next managers natively.

> **CLO dropped** — CodeLinaro `msm-5.15` has too many conflicts with clang-r547379. GKI follows AOSP LTS upstream which is more stable.

---

## Droidspaces Support

This kernel ships with full [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) container support out of the box.

Enabled configs: `SYSVIPC` · `IPC_NS` · `PID_NS` · `POSIX_MQUEUE` · `DEVTMPFS` · Netfilter extras

kABI fix applied for GKI < 6.12 to prevent vendor module crashes on boot.

> **SuSFS users:** disable **"HIDE SUS MOUNTS FOR ALL PROCESSES"** in SuSFS4KSU settings, otherwise containers will fail to start.

Confirmed working on sapphire — see [community-supported devices](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/community-supported-devices.md).

---

## Build Details

| | |
|--|--|
| Source | `android.googlesource.com/kernel/common` |
| Branch | `android13-5.15-lts` |
| Toolchain | Clang r547379 (topnotchfreaks) |
| LTO | Thin |
| Schedule | Manual dispatch |

---

## Setup

### Telegram Notifications (Optional)

1. Create a bot via [@BotFather](https://t.me/BotFather), copy the token
2. Get your chat ID: `https://api.telegram.org/botYOUR_TOKEN/getUpdates`
3. Add to repo → **Settings → Secrets → Actions**:

| Secret | Value |
|--------|-------|
| `TELEGRAM_BOT_TOKEN` | your bot token |
| `TELEGRAM_CHAT_ID` | your chat ID |

### Run a Build

Actions tab → `Build Kernels — AIO` → **Run workflow**

Select ZIP packaging mode:
- `per-variant` — individual ZIP per variant
- `aio` — single ZIP with all images
- `both` — individual ZIPs + AIO ZIP

---

## Installation

> ⚠️ **Flash via OrangeFox / TWRP only.**

1. Download ZIP from [Releases](../../releases)
2. Boot into recovery
3. Flash the ZIP
4. Reboot

> Using **Magisk**? Re-patch your boot image after flashing.

---

## Credits

- [WildKernels](https://github.com/WildKernels) — Wild-KSU
- [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) — SukiSU-Ultra
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS kernel patch
- [sidex15](https://github.com/sidex15/susfs4ksu-module) — SUSFS module
- [ravindu644](https://github.com/ravindu644/Droidspaces-OSS) — Droidspaces
- [vc-teahouse](https://github.com/vc-teahouse/Baseband-guard) — Baseband Guard
- [topnotchfreaks](https://github.com/topnotchfreaks) — Clang toolchain
- Google/AOSP — kernel source

---

**Telegram:** [@home_yu_chat](https://t.me/home_yu_chat) · **Issues:** [open here](../../issues)
