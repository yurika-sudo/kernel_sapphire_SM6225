# GKI-Legacy Compatibility Variants

## Purpose

Compatibility shims for the GKI-Legacy tree (pinned to 5.15.123, deprecated/android13-5.15-2023-10). Used when a `patches/common` patch does not apply to that tree.

## Resolution rule

For `SOURCE_TYPE=gki-legacy`: if a file with the same name exists in this directory, it is used **INSTEAD** of the `patches/common` patch of that name; otherwise the common patch is tried and, if it does not apply on 5.15.123, it is reported as needing manual review and skipped (the build continues).

## Verified variants

The following files were present in this directory at the time of writing:

- `rcu-hurry-migration-net-5.15.patch`

## Verified pipeline status on 5.15.123

- 82 of 92 common patches apply
- 10 skipped (not yet ported to 5.15.123)
- KSU-Next and SukiSU-Ultra integrations verified: driver linked, SUSFS applies, LINUX_VERSION_CODE pins skipped because the legacy tree is not spoofed

## Not yet ported to 5.15.123

The following common patches do not apply on 5.15.123 and have no legacy variant yet:

- `bbrv3-5.15-sapphire.patch` — TCP struct divergence on 5.15.123
- `binder-get-node-fastpath-6.12-5.15.patch` — new binder API path
- `cfs-bandwidth-kabi-safe-gki-5.15-sapphire.patch` — already covered by the earlier cass patch
- `kernel-release-spoof-6.12-5.15.patch` — legacy variant still pending (proc osrelease spoof differs on 5.15.123)
- `qcom-logbuf-print-caller-arity-fix.patch` — target file `drivers/soc/qcom/qcom_logbuf_boot_log.c` does not exist on 5.15.123
- `rcu-lazy-flush-3s-module-param.patch` — missing LAZY_FLUSH_JIFFIES define
- `sched-cambyses-v0.7.0-5.15.patch` — scheduler core divergence on 5.15.123
- `schedutil-rate-limit-latency-6.12-5.15.patch` — new scheduler API
- `walt-early-migrate-battery.patch` — target file `kernel/sched/walt/sysctl.c` does not exist on 5.15.123
- `zstd-upgrade-v157.patch` — new zstd API and files missing on 5.15.123

## Not applicable on 5.15.123 (target file absent)

- `blk-adios-rebalance.patch` — not applicable on 5.15.123

## Note

Ports are still in progress and the list will shrink as variants land.