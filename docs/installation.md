# Installation

> ⚠️ **Flash via OrangeFox / TWRP only.**

1. Download ZIP from [Releases](https://github.com/yurika-sudo/kernel_sapphire_SM6225/releases)
2. Boot into recovery
3. Flash the ZIP
4. Reboot

> Using **Magisk**? Re-patch your boot image after flashing.

---

## Known Issues

**KSU / SukiSU manager shows "Failed to update App Profile"**
Affects older stable manager builds. Update to the latest CI manager build — [get it here](https://t.me/tmplogchat/310).

## Manager

The kernel embeds a specific KSU version code (shown in release notes, e.g. `33169`).
Your manager APK must match that code — a mismatch means apps can't be granted root.

**Use the CI Build links in the release notes, not the stable release.**

- If it shows `Failed to update App Profile` → wrong manager version.
- Correct manager build is always linked directly in the release body.

> This applies to both KSU-Next and SukiSU variants, on Android 13, 14, and 15+.

### Finding the Manager in CI Artifacts

Click the CI Build link → download the artifact ZIP → look for the file named `manager` or `manager-spoofed` (depending on variant). Unzip and install the APK.

If you see "absolute gibberish" on the artifacts page: you're looking at the raw artifact list. Just grab any ZIP and extract it — the `manager` APK is inside.

---

## Troubleshooting

### Bootloop (Stuck on Boot Animation)

Force reboot: Hold **Power** until screen goes black (~5s), then immediately hold **Vol+** while powering back on to enter recovery. Navigate to **root/Mount → root /data/adb**, then delete the `adb` folder. Reboot. install modules one at a time to find the culprit.

### Splash Screen Loop (5 Second Restart Cycle)

Indicates a module conflict or incompatible root hook. fix: go to fastboot and flash the ROM boot.img.

**If you need help:** You must have a **PC**, respond in **English** (minimal), and respond **fast**. DM [@superuseryu](https://t.me/home_yu_chat) directly — slow response = dropped support. This is a personal project; debug sessions are time-sensitive.
