# msm-5.15 Kernel Builder

Automated kernel builder for **Redmi Note 13 4G/NFC (sapphire/sapphiren)** — built for `android13-5.15` devices.

> **Why only sapphire/sapphiren?** Don't wanna risk it, don't have any other device.
>
> If you want to request support for another device, hit me up on [Telegram](https://t.me/home_yu_chat). You accept all risks and take full responsibility — be ready for testing. Bootloop/brick ain't on me.

---

## Variants

**GKI + Wild-KSU**
- Source: AOSP `android13-5.15-lts`
- Root: Wild-KSU (canary) + SUSFS + BBG

**GKI NoKSU**
- Source: AOSP `android13-5.15-lts`
- Root: ❌ Vanilla

All variants include: **BBRv1 + Westwood TCP** · **IP_SET** · **Thin LTO** · **MGLRU**

> **CLO dropped** — CodeLinaro `msm-5.15` has too many source-level conflicts with modern GKI toolchain (clang-r547379). GKI follows AOSP LTS upstream which is more stable for automated weekly builds.

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
3. Add to repo → **Settings → Secrets → Actions**:

| Secret | Value |
|--------|-------|
| `TELEGRAM_BOT_TOKEN` | your bot token |
| `TELEGRAM_CHAT_ID` | your chat ID |

### Run a Build

Actions tab → `Build Kernel` → **Run workflow**

---

## Releases

Each build produces **2 separate ZIPs** — one per variant:

| File | Source | Root |
|------|--------|------|
| `AnyKernel3_GKI_KSU_{date}.zip` | AOSP GKI | Wild-KSU + SUSFS |
| `AnyKernel3_GKI_NoKSU_{date}.zip` | AOSP GKI | Vanilla |

- **Stable releases** → tagged `v{susfs_version}`, scheduled Sunday builds
- **Testing pre-releases** → tagged `{susfs_version}-testing`, manual dispatch

---

## Installation

> ⚠️ **Flash via OrangeFox / TWRP only.**

1. Download the ZIP for your preferred variant from [Releases](../../releases)
2. Boot into recovery
3. Flash the ZIP
4. Reboot

> ⚠️ Using **Magisk**? Re-patch your boot image after flashing.

---

## Disclaimer

Built and tested on sapphire/sapphiren only. Flash at your own risk, always backup first.

---

## Credits

- [WildKernels](https://github.com/WildKernels) — Wild-KSU
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS
- [vc-teahouse](https://github.com/vc-teahouse/Baseband-guard) — Baseband Guard
- [topnotchfreaks](https://github.com/topnotchfreaks) — Clang toolchain
- Google/AOSP — kernel source

---

**Telegram:** [@home_yu_chat](https://t.me/home_yu_chat) · **Issues:** [open here](../../issues)
