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
