# Config Blacklist

> Maintainer reference only. Not user-facing.

## Do not re-add

| Config | Root Cause |
|---|---|
| `CONFIG_PRINTK` | Removes `printk` from vmlinux exports — all vendor `.ko` fail |
| `CONFIG_PSI` | LMKD hard dependency |
| `CONFIG_SCHED_DEBUG` | `sysctl_sched_features` in GKI ABI contract |
| `CONFIG_SCHEDSTATS` | `struct sched_entity` layout change → KMI violation |
| `CONFIG_PAGE_OWNER` | Disables `PAGE_EXTENSION` → vendor `.ko` `page_ext_get()` crash |
| `CONFIG_DEBUG_BUGVERBOSE` | `struct bug_entry` loses `file`+`line` → `.bug_table` misparse in vendor `.ko` |
| `CONFIG_UCLAMP_BUCKETS_COUNT` | Device value is `20` — changing breaks vendor `.ko` struct alignment |
| `CONFIG_CGROUP_DEVICE` | Required by `android-base.config` |
| `CONFIG_CFG80211=y` | Must be `=m` — Qualcomm `wlan.ko` module dep chain |
| `CONFIG_MAC80211=y` | Same as `CFG80211` |
| `CONFIG_IP_TABLES=y` | Must be `=m` — `netd` expects `modprobe` |

## Safe to disable

| Config | Note |
|---|---|
| `CONFIG_UBSAN` | Bisect confirmed |
| `CONFIG_RCU_TRACE` | Doesn't exist in 5.15, no-op |
| `CONFIG_DEBUG_MISC` | Pure Kconfig wrapper, zero runtime impact |
