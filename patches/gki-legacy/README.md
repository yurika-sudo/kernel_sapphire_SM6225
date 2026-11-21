# GKI-Legacy patch set (5.15.123)

This directory contains the GKI-Legacy patch set, one file per common patch, applied INSTEAD of patches/common when SOURCE_TYPE=gki-legacy. The set is pinned to Linux kernel 5.15.123 and maintained by scripts/sync-legacy-patches.sh and scripts/check-legacy-patches.sh.

## Contents

- **patches/gki-legacy/** - The patch set that applies cleanly on 5.15.123. See PENDING.txt for the not-ported list. These replace the corresponding patches from patches/common/ when building for the GKI-Legacy tree.
- **patches/gki-legacy/PENDING.txt** - Common patches that are not yet ported to 5.15.123, each listed with a reason (missing files, unsupported APIs, build-speed disabled drivers, or the 6.x guard macro being unavailable). These patches are skipped during a gki-legacy build.
- **patches/gki-legacy-overrides/** - Rebuilt versions of specific common patches that cannot apply on 5.15.123 as-is. Currently contains the CVE-2026-64560 posix-cpu-timers UAF fix variant (the common version uses `guard(rcu)()` which is unavailable on 5.15.123) and the 5.15.123 rebuild of `cfs-bandwidth-kabi-safe-gki-5.15-sapphire.patch`.
- **patches/gki-legacy/** - legacy-only compatibility patches that add symbols or macros required by out-of-tree integrations (e.g. SUSFS uses `VMA_PAD_START`, which only exists on trees with pgsize_migration support) or by the legacy build itself. These are allowed extra files. Currently: `legacy-0001-vma-pad-start-compat.patch` (VMA_PAD_START), `legacy-0002-legacy-api-shims.patch` (call_rcu_hurry), `legacy-0003-legacy-cleanup-guard.patch` (upstream guard infrastructure: `include/linux/cleanup.h`, the `__cleanup` attribute and the spinlock lock guard, needed by the ADIOS scheduler patch).
- **PENDING.txt** - Lists the common patches that are not ported yet, with the real file+line reason for each.

## Maintenance scripts

- **scripts/sync-legacy-patches.sh** — Regenerates patches/gki-legacy/ from patches/common/ minus the names in PENDING.txt and the build-wide skip (rtl8188gu-driver-5.15-sapphire), then overlays every file from patches/gki-legacy-overrides/. Prints what was copied and what was skipped. Never touches patches/common/.
- **scripts/check-legacy-patches.sh** — Drift detector. Exits non-zero on any problem:
  - Every common patch not in PENDING.txt and not build-wide skipped must exist in patches/gki-legacy/ and be byte-identical to the common file, unless covered by patches/gki-legacy-overrides/ (then identical to the override).
  - Every file in patches/gki-legacy/ must match a common file, an override, or be listed as rebuilt in this README.
  - Every name in PENDING.txt must exist in patches/common/.
  - Prints "legacy set: N patches, M pending".

## Build integration

When SOURCE_TYPE=gki-legacy, scripts/apply-patches.sh applies only patches/gki-legacy/*.patch in sorted order via the apply_patch helper. patches/common is not touched; it remains the AIO (all-variants) set for other source types.

## CVE note

The common version of the CVE-2026-64560 posix-cpu-timers UAF fix uses `guard(rcu)()` which is unavailable on 5.15.123. The override in patches/gki-legacy-overrides/ replaces it with `synchronize_rcu()` — a legacy rebuild still pending for full compatibility.