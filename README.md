# Seiran Kernel

[![Telegram](https://img.shields.io/badge/Telegram-Group_Review-blue?logo=telegram&style=flat-square)](https://t.me/tmplogchat)
[![Telegram](https://img.shields.io/badge/Telegram-Sapphire_Chat-blue?logo=telegram&style=flat-square)](https://t.me/home_yu_chat)
[![XDA](https://img.shields.io/badge/XDA-Thread-orange?logo=xda-developers&style=flat-square)](https://xdaforums.com/t/kernel-seiran-kernel-for-redmi-note-14-pro-sapphire-sapphiren.47450073/)

Custom Android kernel for **sapphire / sapphiren** (Redmi Note 14 Pro). GKI `android13-5.15-lts`, KernelSU-Next with **built-in SUSFS**, DroidSpaces container support. Built by Actions — no local build environment.

**[Download the latest release →](https://github.com/fynks/kernel_sapphire_SM6225/releases/latest)**

---

## Why this kernel

- **SUSFS is in-tree, not bolted on.** Path / mount / kstat / uname / cmdline hiding comes from `CONFIG_KSU_SUSFS*` in the KernelSU-Next `dev-susfs` branch, applied with the `susfs4ksu` kernel patch in the same pass. A kernel that builds but boots with root visible is treated as a failure, not a warning.
- **DroidSpaces works out of the box.** `SYSVIPC`/`POSIX_MQUEUE` move `struct task_struct`, so the build applies upstream's kABI padding patch before enabling them and stops if it does not apply. See [docs/features.md](./docs/features.md#droidspaces-support).
- **The release tag follows the SUSFS module** (`v1.5.2+_R28`-style) because that is what you install next to the kernel; `seiran-core.zip` (ZRAM + governor tweaks) ships as a module in the same release.
- **One kernel, pinned upstreams.** Every version this build compiles against is recorded in [sources/source-pins.json](./sources/source-pins.json) — and only rewritten after a CI build has passed against it.

One-off features, per-group changelog and how to recover after a failed flash: **[docs/features.md](./docs/features.md)** · **[docs/installation.md](./docs/installation.md)**

## Repository structure

```
.github/
  actions/setup-env/      apt deps + build date — the only composite action left
  workflows/
    build.yml             build · pack · release (manual, or every 5 days; schedule never publishes)
    check-updates.yml     weekly upstream check → verify build → bump the pin file
  copilot-instructions.md Conventional Commits + repo rules for AI-assisted changes
scripts/                  17 entrypoints + the apply_patch helper — every step's
                          behaviour lives here, not in the YAML
patches/
  common/                 applied always
  testing/                applied for build_type=testing
sources/source-pins.json  KSU-Next · SUSFS · DroidSpaces · GKI sublevel
modules/seiran-core/      ZRAM + governor tweaks shipped by the kernel
AnyKernel3/               flashable package (defconfig is an artifact, not tracked)
docs/                     variants · features · installation · ci · about · credits
```

## Building it yourself

Fork, then in **Actions → Build & Release — Seiran GKI → Run workflow**:

1. No setup required. `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` are optional and only control notifications.
2. Push your own `AnyKernel3/anykernel.sh` config to the device you are targeting before you publish.
3. `skip_release: true` gives you the flashable ZIP as a workflow artifact (7 days) without touching releases.

The build clones the GKI kernel tree (~15 min), so a run is ~35–50 min and only needs 16 GB of RAM on an `ubuntu-latest` runner. Nothing in `scripts/` assumes a specific fork or device beyond the paths in the header comments (`DEFCONFIG`, `DEFCONFIG_PATH`, `KERNEL_DIR`, `WORK_DIR`).

## Related repos

- **DroidSpaces** — [ravindu644/Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS)
- **KernelSU-Next (built-in SUSFS)** — [pershoot/KernelSU-Next@dev-susfs](https://github.com/pershoot/KernelSU-Next/tree/dev-susfs)
- **SUSFS** — [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) · [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module)
- **Baseband Guard** — [vc-teahouse/Baseband-guard](https://github.com/vc-teahouse/Baseband-guard)

Full list: **[docs/credits.md](./docs/credits.md)**

---

## License

This repo's own scripts, workflows and modules are GPL v2. The kernel is GPL-2.0 under the licenses of its upstream sources (GKI, KernelSU-Next, SUSFS, DroidSpaces) — see each project's own license.
