# Variants

## Variants

| Variant | Source | Root | Extras |
|---------|--------|------|--------|
| GKI-Ksun | AOSP LTS | KernelSU-Next + SUSFS | BBG |
| GKI-BakaSU | AOSP LTS | BakaSU + SUSFS | — |
| GKI-NoKSU | AOSP LTS | Vanilla | — |
| GKI-Legacy-Ksun | AOSP 2023-10 (legacy) | KernelSU-Next + SUSFS | BBG |
| GKI-Legacy-BakaSU | AOSP 2023-10 (legacy) | BakaSU + SUSFS | — |
| GKI-Legacy-NoKSU | AOSP 2023-10 (legacy) | Vanilla | — |

**Supported Android versions:** GKI-Legacy targets Android 13/14 baseline only — WildKernels patches + KSU/SuSFS, no performance scheduler patches. Main **GKI** targets Android 15+ ROMs.

---

## Build Details

| | GKI | GKI-Legacy |
|--|-----|------------|
| Source | `android.googlesource.com/kernel/common` | `android.googlesource.com/kernel/common` |
| Branch | `android13-5.15-lts` | `deprecated/android13-5.15-2023-10` |
| Config fragment | — | — |
| Toolchain | Neutron Clang 24 | Clang r450784e |
| LTO | Thin | Thin |
