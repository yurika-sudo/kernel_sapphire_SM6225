# Installation

> ⚠️ **Back up first — always.**
> Back up anything you don't want to lose, and keep a copy of your current ROM's `boot.img` on hand before you start. Custom-ROM behavior on this device isn't always predictable, so treat these as precautions, not optional steps — especially if you're new to this.
>
> Not strictly mandatory, but if you're unsure: from recovery, delete the `/adb` folder (path: `/data/adb`) before flashing, particularly if you're coming from a different kernel or root setup.

## What you need

1. **The kernel ZIP** — `AK3-Seiran-GKI-<version>-<yyyy-mm>.zip` (AnyKernel3, flashes `Image` only).
2. **`seiran-core.zip`** — KSU/Magisk module with `zram.ko` + `zsmalloc.ko` and the governor tweaks. Without it ZRAM does not exist. Flash it *after* the kernel.
3. **The KernelSU-Next manager APK** whose version code matches the kernel — the release body links the exact CI build.

There is one kernel build; nothing to choose. [variants.md](./variants.md) covers why, and how to get the older-ABI build back if you are on an Android 13/14 ROM.

## Flashing

Pick whichever fits your setup:

**A. Custom recovery (OrangeFox / TWRP)**
1. Download ZIP from [Releases](https://github.com/superuseryu/kernel_sapphire_SM6225/releases)
2. Boot into recovery
3. Flash the ZIP
4. Reboot

**B. Any flasher app** — Any kernel flasher, it's simple, just follow the menu according to the app you are using.

**C. KernelSU-Next manager's built-in flash feature** — open the manager app → Flash Recovery ZIP / flash kernel → pick the AnyKernel3 ZIP. No recovery needed.

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

**Manager shows "Failed to update App Profile" / root is never granted**
Almost always a manager-to-kernel version mismatch. See below.

## Manager

The kernel embeds a KernelSU version code — `30000 + <commit count>`, e.g. `32906` — and it is printed in every release body. Your manager APK has to be the build for that code; a *newer* manager against this kernel is exactly what produces `Failed to update App Profile`.

**Use the CI link in the release body, not the stable release.** The link points at the KernelSU-Next `Build Manager CI` run for the commit this kernel's version code derives from, and the two APKs from that run (`KernelSU-Next` release / spoofed) are attached to the release as well.

If you only see a raw artifact list: download the `manager` ZIP and install the `*-arm64-v8a-release.apk` inside (the `universal` one works too).

> KernelSU-Next's CI artifacts expire after 90 days. If the linked run has expired, the newest successful `Build Manager CI` run on `dev` is the next best thing — and if the version codes differ, flash the kernel build that matches instead.

---

## Troubleshooting

### Bootloop (Stuck on Boot Animation)

Force reboot: Hold **Power** until screen goes black (~5s), then immediately hold **Vol+** while powering back on to enter recovery. Navigate to **root/Mount → root /data/adb**, then delete the `adb` folder. Reboot. install modules one at a time to find the culprit.

### Splash Screen Loop (5 Second Restart Cycle)

You're cooked if you didn't back up your ROM's `boot.img` (see the backup note at the top). Flash it back: `fastboot flash boot path-to-boot.img`. Root cause isn't always obvious, but if you jumped straight to a **testing build**, that's usually it — stick to the **stable build** in [Releases](https://github.com/superuseryu/kernel_sapphire_SM6225/releases).

**If you need help:** You must have a **PC**, respond in **English** (minimal), and respond **fast**. DM [@superuseryu](https://t.me/home_yu_chat) directly — slow response = dropped support. This is a personal project; debug sessions are time-sensitive.
