# msm-5.15 Kernel Builder

Automated kernel builder for **Redmi Note 13 4G/NFC (sapphire/sapphiren)** â€” built for `android13-5.15` devices.

> **Why only sapphire/sapphiren?** Don't wanna risk it, don't have any other device.
>
> If you want to request support for another device, hit me up on [Telegram](https://t.me/home_yu_chat). You accept all risks and take full responsibility â€” be ready for testing. Bootloop/brick ain't on me.

---

## Variants

**GKI + Wild-KSU**
- Source: AOSP `android13-5.15-lts`
- Root: Wild-KSU (canary) + SUSFS + BBG

**GKI NoKSU**
- Source: AOSP `android13-5.15-lts`
- Root: âŒ Vanilla

All variants include: **BBRv1 + Westwood TCP** Â· **IP_SET** Â· **Thin LTO** Â· **MGLRU**

> **CLO dropped** â€” CodeLinaro `msm-5.15` has too many source-level conflicts with modern GKI toolchain (clang-r547379). GKI follows AOSP LTS upstream which is more stable for automated weekly builds.

---

## Build Details

| | GKI |
|--|-----|
| Source | `android.googlesource.com/kernel/common` |
| Branch | `android13-5.15-lts` |
| Toolchain | Clang r547379 (topnotchfreaks) |
| LTO | thin |

Auto-build every Sunday 00:00 UTC. Both variants build in parallel, each released as a separate ZIP.

---

## Setup

### Telegram Notifications (Optional)

1. Create a bot via [@BotFather](https://t.me/BotFather), copy the token
2. Get your chat ID:
   ```
   https://api.telegram.org/botYOUR_TOKEN/getUpdates
   ```
3. Add to repo â†’ **Settings â†’ Secrets â†’ Actions**:

| Secret | Value |
|--------|-------|
| `TELEGRAM_BOT_TOKEN` | your bot token |
| `TELEGRAM_CHAT_ID` | your chat ID |

### Run a Build

Actions tab â†’ `Build Kernel` â†’ **Run workflow**

---

## Releases

Each build produces **2 separate ZIPs** â€” one per variant:

| File | Source | Root |
|------|--------|------|
| `AnyKernel3_GKI_KSU_{date}.zip` | AOSP GKI | Wild-KSU + SUSFS |
| `AnyKernel3_GKI_NoKSU_{date}.zip` | AOSP GKI | Vanilla |

- **Stable releases** â†’ tagged `v{susfs_version}`, scheduled Sunday builds
- **Testing pre-releases** â†’ tagged `{susfs_version}-testing`, manual dispatch

---

## Installation

> âš ï¸ **Flash via OrangeFox / TWRP only.**

1. Download the ZIP for your preferred variant from [Releases](../../releases)
2. Boot into recovery
3. Flash the ZIP
4. Reboot

> âš ï¸ Using **Magisk**? Re-patch your boot image after flashing.

---

## Disclaimer

Built and tested on sapphire/sapphiren only. Flash at your own risk, always backup first.

---

## Credits

- [WildKernels](https://github.com/WildKernels) â€” Wild-KSU
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) â€” SUSFS
- [vc-teahouse](https://github.com/vc-teahouse/Baseband-guard) â€” Baseband Guard
- [topnotchfreaks](https://github.com/topnotchfreaks) â€” Clang toolchain
- Google/AOSP â€” kernel source

---

**Telegram:** [@home_yu_chat](https://t.me/home_yu_chat) Â· **Issues:** [open here](../../issues)
