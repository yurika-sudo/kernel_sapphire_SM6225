# Installation

> ⚠️ **Back up first — always.**
> Back up anything you don't want to lose, and keep a copy of your current ROM's `boot.img` on hand before you start. Custom-ROM behavior on this device isn't always predictable, so treat these as precautions, not optional steps — especially if you're new to this.
>
> Not strictly mandatory, but if you're unsure: from recovery, delete the `/adb` folder (path: `/data/adb`) before flashing, particularly if you're coming from a different kernel or root setup.

## Which variant do I flash?

- **On an Android 13 / 14 ROM →** use a **GKI-Compat** variant.
- **On an Android 15+ ROM →** use the main **Seiran-GKI** (or **CLO**) variant.

See [variants.md](./variants.md) for the full list and why GKI-Compat is the one to pick on older ROMs.

## Flashing

Pick whichever fits your setup:

**A. Custom recovery (OrangeFox / TWRP)**
1. Download ZIP from [Releases](https://github.com/superuseryu/kernel_sapphire_SM6225/releases)
2. Boot into recovery
3. Flash the ZIP
4. Reboot

**B. Any flasher app** — Any kernel flasher, it's simple, just follow the menu according to the app you are using.

**C. KSU-Next / SukiSU manager's built-in flash feature** — open the manager app → flash kernel → select the AnyKernel3 ZIP. No recovery needed.

> Using **Magisk**? Re-patch your boot image after flashing.

**No recovery and no built-in flasher available?** Sideload it instead:
```
adb sideload AK3-<name>.zip
```

### Don't have a custom recovery yet?

This is a bit off-topic, but if you're on stock recovery: grab OrangeFox for this device here → https://orangefox.download/device/65a5a3287ac2a93129dc9543

1. Reboot to fastboot: hold **Power** for ~5–10s until the screen goes black, release, then hold **Vol-** until the fastboot screen appears. (Make sure fastboot drivers are installed first if you're on Windows.)
2. Flash it:
   ```
   fastboot flash recovery path-to-recovery.img
   ```
   > ⚠️ **Do not run `fastboot boot path-to-recovery.img` on this device.** The official recovery documentation for sapphire/sapphiren specifically calls for `fastboot flash`, not `fastboot boot` — this has been called out deliberately, not an oversight.

If a kernel build you're using (e.g. a testing build) ever splash-screen-loops or bootloops, recover with:
```
fastboot flash boot path-to-boot.img
```

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

You're cooked if you didn't back up your ROM's `boot.img` (see the backup note at the top). Flash it back: `fastboot flash boot path-to-boot.img`. Root cause isn't always obvious, but if you jumped straight to a **testing build**, that's usually it — stick to the **stable build** in [Releases](https://github.com/superuseryu/kernel_sapphire_SM6225/releases).

**If you need help:** You must have a **PC**, respond in **English** (minimal), and respond **fast**. DM [@superuseryu](https://t.me/home_yu_chat) directly — slow response = dropped support. This is a personal project; debug sessions are time-sensitive.
