# Variants

One build. No matrix.

| | |
|--|--|
| **Name** | Seiran-GKI |
| **Source** | `android.googlesource.com/kernel/common` @ `android13-5.15-lts` (GKI 2.0, `gki_defconfig`) |
| **Root** | [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) — built-in SUSFS fork |
| **Hiding** | SUSFS in-tree (`CONFIG_KSU_SUSFS`) + Baseband Guard + NoMount |
| **Containers** | DroidSpaces, built in |
| **Modules** | `zram.ko`, `zsmalloc.ko`, `encore_fas.ko`, ath9k chain → shipped by `seiran-core.zip` |
| **Target** | Android 15+ ROMs on sapphire / sapphiren |
| **Output** | `AK3-Seiran-GKI-<version>-<yyyy-mm>.zip` (AnyKernel3) |

---

## Why KernelSU-Next and not the others

- **Built-in SUSFS** is what this kernel is for. Upstream KernelSU-Next only carries SUSFS as a separate loadable module (`susfs_guard_lkm.ko`), and its `dev` branch has no `CONFIG_KSU_SUSFS*` symbols at all. [pershoot/KernelSU-Next@`dev-susfs`](https://github.com/pershoot/KernelSU-Next/tree/dev-susfs) is the branch that integrates SUSFS in-tree: its own Kconfig, `susfs_init()` called from `kernel/core/init.c`, and the inline-hook sucompat that SUSFS v2 expects. That is what `scripts/setup-ksu.sh` clones.
- **Manager compatibility is version-code based.** The kernel bakes in `KSU_VERSION = 30000 + <commits>`, so the manager APK has to come from the matching CI build — see [installation.md](installation.md#manager). The release notes link the exact run.
- **One KSU dialect keeps the integration honest.** ReSukiSU/SukiSU-Ultra needed three separate workarounds here (a dropped `kernel_umount_feature_set`, SUSFS `exec.c` hooks they never ship, their own Kconfig set). Those are gone with them.

## Why only GKI

CLO (`git.codelinaro.org/clo/la/kernel/msm-5.15`, `vendor/bengal_GKI.config` fragment) was the second base: Qualcomm's own tree, kept because it builds with the vendor's display/camera drivers in place of the GKI ones. It cost a duplicate patch set (`patches/clo-only/` — its own FAS and zstd variants), a second toolchain, a source cache and three extra matrix jobs, and every upstream bump had to survive both paths. The GKI build is what the device tree and the module set in `seiran-core.zip` are maintained against.

`patches/gki-compat-only/` (the `android13-5.15-2023-10` / 5.15.123 tree for Android 13–14 ROMs) is gone for the same reason. If you need that target, it is one `clone-source.sh` branch away in the git history.

---

## How versions are chosen

| Component | Ref | Pinned in |
|---|---|---|
| Kernel | branch head of `android13-5.15-lts` | `gki_branch` (sublevel recorded for the ccache key) |
| KernelSU-Next | branch head of `pershoot/KernelSU-Next@dev-susfs` | `ksun_repo` / `ksun_branch`; `ksun_tag` records the release it contains |
| SUSFS kernel patch | branch head of `simonpunk/susfs4ksu@gki-android13-5.15` | `susfs_branch`; `susfs_version` records e.g. `v2.3.0` |
| SUSFS userspace module | latest release | `susfs_module_tag` |
| DroidSpaces | **exact release tag** — the kABI patch URL is built from it | `droidspaces_tag` |

Only the DroidSpaces ref is a hard pin, because its patch is fetched by URL and a silent move upstream would change or drop what we compile against. The rest float on their branches (that is how the community ships these), and [sources/source-pins.json](../sources/source-pins.json) records what was last verified. See [ci.md](ci.md) for how that file gets updated.
