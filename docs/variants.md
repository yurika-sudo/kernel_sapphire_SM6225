# Variants

## Variants

| Variant | Source | Root | Extras |
|---------|--------|------|--------|
| GKI-Ksun | AOSP LTS | KernelSU-Next + SUSFS | BBG |
| GKI-BakaSU | AOSP LTS | BakaSU + SUSFS | — |
| GKI-NoKSU | AOSP LTS | Vanilla | — |
| GKI-Compat-Ksun | AOSP 2023-10 (deprecated) | KernelSU-Next + SUSFS | BBG |
| GKI-Compat-BakaSU | AOSP 2023-10 (deprecated) | BakaSU + SUSFS | — |
| GKI-Compat-NoKSU | AOSP 2023-10 (deprecated) | Vanilla | — |

**Supported Android versions:** GKI-Compat targets an older GKI ABI and works across Android 13–17 — use it if your ROM is on Android 13 or 14. Main **GKI** targets the newer interfaces and is for Android 15+ ROMs.

---

## Build Details

| | GKI | GKI-Compat |
|--|-----|------------|
| Source | `android.googlesource.com/kernel/common` | `android.googlesource.com/kernel/common` |
| Branch | `android13-5.15-lts` | `deprecated/android13-5.15-2023-10` |
| Config fragment | — | — |
| Toolchain | Neutron Clang 24 | Clang r450784e |
| LTO | Thin | Thin |
