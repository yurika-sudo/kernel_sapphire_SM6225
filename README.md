# msm-5.15 Kernel Builder (Testing)

Automated kernel builder for **Redmi Note 13 4G/NFC (sapphire/sapphiren)** — built specifically for `android13-5.15` devices.

> **Why only sapphire/sapphiren?** Don't wanna risk it, don't have any other device. :v
>
> If you actually wanna request support for another device, just send a message in my [Telegram channel](https://t.me/home_yu_chat). Just know you accept all the risks and take full responsibility — you gotta be ready for testing. Bootloop/brick ain't my responsibility as the dev.

---

## Variants

**GKI + Wild-KSU**
- Source: AOSP `android13-5.15-lts`
- KernelSU: ✅ Wild-KSU + SUSFS
- Image: `Image.gki.ksu`

**GKI NoKSU**
- Source: AOSP `android13-5.15-lts`
- KernelSU: ❌
- Image: `Image.gki.noksu`

**CLO + Wild-KSU**
- Source: CodeLinaro `msm-5.15`
- KernelSU: ✅ Wild-KSU + SUSFS
- Image: `Image.clo.ksu`

**CLO NoKSU**
- Source: CodeLinaro `msm-5.15`
- KernelSU: ❌
- Image: `Image.clo.noksu`

All variants include: **BBG** · **BBRv1 + Westwood TCP**

> **GKI vs CLO** — GKI follows AOSP LTS upstream. CLO is Qualcomm's own kernel fork with MSM-specific patches, potentially better for Snapdragon devices.

---

## Build Details

**GKI (AOSP)**
- Source: `android.googlesource.com/kernel/common`
- Branch: `android13-5.15-lts`
- Toolchain: Clang r547379
- LTO: Thin
- Build Time: ~40 min

**CLO (CodeLinaro)**
- Source: `git.codelinaro.org/clo/la/kernel/msm-5.15`
- Branch: `kernel.lnx.5.15.r1-rel`
- Toolchain: Clang r547379
- LTO: Thin
- Build Time: ~43 min

Auto-build every Sunday 00:00 UTC (all 4 variants in parallel).

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

Actions tab → `Build Kernel AIO` → **Run workflow**

All 4 variants build in parallel, packaged into a single AIO ZIP on completion.

---

## Installation

<details>
<summary>Click to expand</summary>

> ⚠️ **Flash via OrangeFox / TWRP only.** Volume key selection does not work in flasher apps.

1. Download the ZIP from [Releases](https://github.com/superuseryu/android13.5.15_SM6225/releases)
2. Boot into recovery
3. Flash the ZIP — recovery will prompt you to choose:

```
Step 1 — Kernel source
  Vol+  →  GKI (AOSP)
  Vol-  →  CLO (CodeLinaro)

Step 2 — KSU variant
  Vol+  →  NoKSU (Vanilla)
  Vol-  →  KSU (Wild-KSU + SUSFS)
```

4. Reboot

> ⚠️ Using **Magisk**? Re-patch your boot image after flashing. `no_magisk_check` is intentionally disabled.

</details>

---

## Disclaimer

Built and tested on sapphire/sapphiren only. Flash at your own risk, always backup first.

---

## Credits

- [WildKernels](https://github.com/WildKernels) — Wild-KSU
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS
- [vc-teahouse](https://github.com/vc-teahouse/Baseband-guard) — Baseband Guard
- [topnotchfreaks](https://github.com/topnotchfreaks) — Clang toolchain
- Google/AOSP · CodeLinaro/Qualcomm — kernel sources

---

**Telegram:** [@home_yu_chat](https://t.me/home_yu_chat) · **Issues:** [open here](https://github.com/superuseryu/android13.5.15_SM6225/issues)
