#!/usr/bin/env bash
# setup-configs.sh — inject kernel configs into the defconfig
#
# env: DEFCONFIG   full path to the defconfig file being edited
#      KERNEL_DIR  kernel source root (used to read the KSU Kconfig)
#
# Two halves: the tuning block (everything the kernel carries regardless of
# root setup) and the KSU/SUSFS block. The KSU block is then reconciled against
# the *actual* Kconfig of the checked-out KernelSU-Next, because SUSFS renames
# and drops symbols between releases and a defconfig line that matches no
# Kconfig symbol is dropped in silence.
set -e

: "${DEFCONFIG:?}"
: "${KERNEL_DIR:=$PWD}"

CF="$DEFCONFIG"
[ -f "$CF" ] || { echo "[ERROR] defconfig not found: $CF" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Base cleanup
# ---------------------------------------------------------------------------
sed -i 's/ cgroup_disable=pressure//'                    "$CF"
sed -i 's/CONFIG_CMDLINE="/&slub_debug=- page_owner=off noirqdebug mitigations=off /' "$CF"
sed -i 's/kasan\.stacktrace=off/kasan=off/'               "$CF"

# Strip symbols already in the base defconfig so the append below can't produce
# a "reassigning symbol" warning (last write wins only by accident).
for SYM in WLAN_VENDOR_ATH \
           PID_NS DEBUG_KINFO \
           NET_SCH_CODEL NET_SCH_FQ_CODEL UBSAN NET_SCH_DEFAULT DEFAULT_NET_SCH DEFAULT_NET_SCH_FQ_CODEL \
           LRU_GEN LRU_GEN_ENABLED NET_SCH_FQ DEBUG_MEMORY_INIT PRINTK_CALLER \
           ZRAM_DEF_COMP_LZORLE ZRAM_DEF_COMP_ZSTD ZRAM_DEF_COMP_LZ4 ZRAM_DEF_COMP_LZO ZRAM_DEF_COMP \
           SCHED_WALT SCHED_WALT_DEBUG CPU_FREQ_GOV_SCHEDUTIL CPU_FREQ_DEFAULT_GOV_SCHEDUTIL \
           TCP_CONG_ADVANCED TCP_CONG_BBR TCP_CONG_BBR3 TCP_CONG_WESTWOOD DEFAULT_TCP_CONG \
           NET_SCH_DEFAULT DEFAULT_NET_SCH; do
  sed -i "/^CONFIG_${SYM}[= ]/d; /^# CONFIG_${SYM} /d" "$CF"
done

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------
cat >> "$CF" << 'EOF'
CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y
CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y
# CONFIG_SCHED_WALT is not set
# CONFIG_SCHED_WALT_DEBUG is not set
CONFIG_TCP_CONG_ADVANCED=y
# CONFIG_TCP_CONG_BBR is not set
CONFIG_TCP_CONG_BBR3=y
CONFIG_TCP_CONG_WESTWOOD=y
# CONFIG_TCP_CONG_BIC is not set
# CONFIG_TCP_CONG_HTCP is not set
CONFIG_DEFAULT_TCP_CONG="bbr3"
CONFIG_NET_SCH_FQ=y
# CONFIG_NET_SCH_FQ_CODEL is not set
CONFIG_NET_SCH_CAKE=y
CONFIG_NET_SCH_PIE=y
CONFIG_NET_SCH_DEFAULT=y
CONFIG_DEFAULT_FQ=y
CONFIG_DEFAULT_NET_SCH="fq"
# CONFIG_IOSCHED_BFQ is not set
# CONFIG_BFQ_GROUP_IOSCHED is not set
CONFIG_MQ_IOSCHED_DEADLINE=y
CONFIG_DEFAULT_MQ_IOSCHED="mq-deadline"
CONFIG_DEFAULT_DEADLINE=y
CONFIG_ZRAM=m
CONFIG_ZSMALLOC=m
CONFIG_ZRAM_WRITEBACK=y
CONFIG_ZRAM_MEMORY_TRACKING=y
# CONFIG_ZRAM_DEF_COMP_LZORLE is not set
# CONFIG_ZRAM_DEF_COMP_ZSTD is not set
CONFIG_ZRAM_DEF_COMP_LZ4=y
# CONFIG_ZRAM_DEF_COMP_LZO is not set
CONFIG_ZRAM_DEF_COMP="lz4"
CONFIG_ZRAM_MULTI_COMP=y
CONFIG_LRU_GEN=y
CONFIG_LRU_GEN_ENABLED=y
CONFIG_LRU_GEN_WALKS_MMU=y
# CONFIG_HZ_100 is not set
# CONFIG_HZ_250 is not set
CONFIG_HZ_300=y
# CONFIG_HZ_1000 is not set
CONFIG_HZ=300
CONFIG_FRAME_WARN=0
CONFIG_WQ_POWER_EFFICIENT_DEFAULT=y
# CONFIG_SLUB_DEBUG_ON is not set
# CONFIG_SLUB_STATS is not set
# CONFIG_DEBUG_LIST is not set
# CONFIG_DEBUG_KINFO is not set
# CONFIG_DEBUG_MEMORY_INIT is not set
# CONFIG_RCU_TRACE is not set
# CONFIG_PRINTK_CALLER is not set
# CONFIG_DEBUG_FS is not set
# CONFIG_DEBUG_MISC is not set
# CONFIG_UBSAN is not set
# CONFIG_F2FS_IOSTAT is not set
CONFIG_NTSYNC=y
CONFIG_SCHED_BORE=y
CONFIG_SCHED_PREFER_SILVER=y
# CONFIG_RCU_LAZY_DEFAULT_OFF is not set
CONFIG_SCHED_CASS=y
CONFIG_MQ_IOSCHED_ADIOS=y
CONFIG_CPU_FREQ_GOV_REFLEX=y
CONFIG_NOMOUNT=y
CONFIG_CPU_IDLE_GOV_NAP=y
CONFIG_UPROBES=y
CONFIG_UPROBE_EVENTS=y
CONFIG_ENCORE_FAS=m
CONFIG_WLAN=y
CONFIG_WLAN_VENDOR_ATH=y
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_ATH9K_HTC=m
CONFIG_ATH=m
CONFIG_ATH9K_HW=m
CONFIG_ATH9K_COMMON=m
CONFIG_CGROUP_PIDS=y
CONFIG_SUSPEND_SKIP_SYNC=y
EOF

# ---------------------------------------------------------------------------
# Root: KernelSU-Next + built-in SUSFS + Baseband Guard
# ---------------------------------------------------------------------------
# Drop any earlier KSU/BBG lines (a fork may have added its own) so the block
# below is the only one — duplicated symbols make olddefconfig pick by luck.
sed -i "/^CONFIG_KSU[A-Z0-9_]*[= ]/d; /^# CONFIG_KSU[A-Z0-9_]* /d; /^CONFIG_BBG[= ]/d" "$CF"

cat >> "$CF" << 'EOF'
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_MAP=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
# CONFIG_KSU_SUSFS_ENABLE_LOG is not set
CONFIG_BBG=y
EOF

# ---------------------------------------------------------------------------
# Reconcile the KSU block with the Kconfig that is actually checked out.
# ---------------------------------------------------------------------------
KCFG="KernelSU-Next/kernel/Kconfig"
[ -L "drivers/kernelsu" ] && KCFG="$(readlink -f drivers/kernelsu)/Kconfig"

if [ -f "$KCFG" ]; then
  AVAIL=$(grep -oE '^[[:space:]]*config (KSU|KSU_SUSFS)[A-Z0-9_]*' "$KCFG" \
            | awk '{print $2}' | sort -u)
  WANTED=$(grep -oE '^#? ?CONFIG_((KSU_SUSFS|KSU)[A-Z0-9_]*)' "$CF" | sed 's/^#* *CONFIG_//' | sort -u)

  for SYM in $WANTED; do
    grep -qx "$SYM" <<< "$AVAIL" && continue
    echo "[WARN] $SYM is not a Kconfig symbol of this KernelSU-Next — dropped"
    sed -i "/^CONFIG_${SYM}[= ]/d; /^# CONFIG_${SYM} /d" "$CF"
  done

  # A SUSFS feature we never mention is a feature that is on/off purely by
  # upstream's default — worth one line in the log whenever that changes.
  for SYM in $AVAIL; do
    case "$SYM" in KSU_SUSFS_*) ;; *) continue ;; esac
    grep -q "^CONFIG_${SYM}[= ]\|^# CONFIG_${SYM} " "$CF" && continue
    echo "[INFO] $SYM not set here — inherits its Kconfig default"
  done

  REQUIRED="KSU KSU_SUSFS KSU_SUSFS_SUS_PATH KSU_SUSFS_SUS_MOUNT KSU_SUSFS_SUS_KSTAT"
  for SYM in $REQUIRED; do
    grep -q "^CONFIG_${SYM}=y$" "$CF" \
      || { echo "[ERROR] $SYM must be =y for the SUSFS build; check the Kconfig upstream" >&2; exit 1; }
  done
else
  echo "[WARN] $KCFG not found — KSU config symbols not validated"
fi

echo "[OK] Configs written"
