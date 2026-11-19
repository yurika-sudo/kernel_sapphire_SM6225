# GKI-Legacy Compatibility Variants

## Purpose

Compatibility shims for the GKI-Legacy tree (pinned to 5.15.123, deprecated/android13-5.15-2023-10). Used when a `patches/common` patch does not apply to that tree.

## Resolution rule

For `SOURCE_TYPE=gki-legacy`: if a file with the same name exists in this directory, it is used **INSTEAD** of the `patches/common` patch of that name; otherwise the common patch is tried and, if it does not apply on 5.15.123, it is reported as needing manual review and skipped (the build continues).

## Verified variants

The following files were present in this directory at the time of writing:

- `rcu-hurry-migration-net-5.15.patch`

## Not yet ported

The following common patches do not apply on 5.15.123 and have no legacy variant yet:

- `0002-logspam-filter-nfc-hwsvc.patch` — printk filter hook not present on 5.15.123
- `0003-logspam-filter-n7-wlan-hdd.patch` — printk filter hook not present on 5.15.123
- `0004-logspam-filter-cmn-mlme.patch` — printk filter hook not present on 5.15.123
- `kernel-release-spoof-6.12-5.15.patch` — the proc osrelease spoof in kernel/utsname_sysctl.c differs structurally on 5.15.123, so the legacy variant is still pending (the AIO variant for 5.15.225 is already regenerated)
- `binder-get-node-fastpath-6.12-5.15.patch` — new binder API path
- `schedutil-rate-limit-latency-6.12-5.15.patch` — new scheduler API: ignore_rate_limit_latency_sensitive
- `prefer_silver_pelt_only.patch` — new Kconfig CONFIG_SCHED_PREFER_SILVER
- `rcu-lazy-flush-3s-module-param.patch` — missing LAZY_FLUSH_JIFFIES define
- `sis-util-llc-idle-scan-5.15-sapphire.patch` — new topology helpers
- `bore-5.15-sapphire.patch` — new Kconfig CONFIG_SCHED_BORE
- `blk-adios-backport.patch` — new files required (block/adios.c and friends)
- `eevdf-backport-sched.patch` — scheduler core divergence on 5.15.123
- `sched-cambyses-v0.7.0-5.15.patch` — scheduler core divergence on 5.15.123
- `sched-eas-asymmetric-down-migration.patch` — scheduler core divergence on 5.15.123
- `cfs-bandwidth-kabi-safe-gki-5.15-sapphire.patch` — already covered by the earlier cass patch
- `zstd-upgrade-v157.patch` — new zstd API and files missing on 5.15.123
- `bbrv3-5.15-sapphire.patch` — TCP struct divergence on 5.15.123
- `cpuidle-poll-cap-100us-6.12-5.15.patch` — port pending (variant failed verification and was removed)
- `vm_swappiness.patch` — port pending (variant failed verification and was removed)
- `watermark-boost-clamp-6.12-5.15.patch` — port pending (variant failed verification and was removed)

## Not applicable on 5.15.123 (target file absent)

- `qcom-logbuf-print-caller-arity-fix.patch` — target file `drivers/soc/qcom/qcom_logbuf_boot_log.c` does not exist
- `walt-early-migrate-battery.patch` — target file `kernel/sched/walt/sysctl.c` does not exist (no WALT scheduler)
- `blk-adios-rebalance.patch` — not applicable on 5.15.123

## Note

Ports are still in progress and the list will shrink as variants land.