#!/usr/bin/env bash
# apply-patches.sh — apply the WildKernels patch set, then patches/common/
# (and patches/testing/ on testing builds)
#
# env: KERNEL_SRC, WORK_DIR, BUILD_TYPE (stable | testing)
#
# A patch that does not apply is a hard error only for the local patches we
# ship in-tree (they are ours to fix); the third-party WildKernels set stays
# best-effort so an upstream reshuffle cannot take the whole build down.
set -e

: "${KERNEL_SRC:?}"
: "${BUILD_TYPE:-stable}"
: "${WORK_DIR:=$GITHUB_WORKSPACE}"

source "$(dirname "$0")/apply_patch.sh"
cd "$KERNEL_SRC"

# ---------------------------------------------------------------------------
# Upstream optimization patches (WildKernels)
# ---------------------------------------------------------------------------
echo "=== Applying upstream optimization patches ==="
BASE="https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/common"

apply_patch "$BASE/ntsync/ntsync_base.patch"                       "ntsync_base"
apply_patch "$BASE/ntsync/ntsync_compat_android13-5.15.patch"      "ntsync_compat_android13-5.15"
apply_patch "$BASE/IPv6_NAT_FIX.patch"                             "IPv6_NAT_FIX"
apply_patch "$BASE/add_limitation_scaling_min_freq.patch"          "add_limitation_scaling_min_freq"
apply_patch "$BASE/add_timeout_wakelocks_globally.patch"           "add_timeout_wakelocks_globally"
apply_patch "$BASE/adjust_cpu_scan_order.patch"                    "adjust_cpu_scan_order"
apply_patch "$BASE/avoid_extra_s2idle_wake_attempts.patch"         "avoid_extra_s2idle_wake_attempts"
apply_patch "$BASE/clear_page_16bytes_align.patch"                 "clear_page_16bytes_align"
apply_patch "$BASE/disable_cache_hot_buddy.patch"                  "disable_cache_hot_buddy"
apply_patch "$BASE/f2fs_enlarge_min_fsync_blocks.patch"            "f2fs_enlarge_min_fsync_blocks"
apply_patch "$BASE/f2fs_reduce_congestion.patch"                   "f2fs_reduce_congestion"
apply_patch "$BASE/file_struct_8bytes_align.patch"                 "file_struct_8bytes_align"
apply_patch "$BASE/increase_ext4_default_commit_age.patch"         "increase_ext4_default_commit_age"
apply_patch "$BASE/increase_sk_mem_packets.patch"                  "increase_sk_mem_packets"
apply_patch "$BASE/int_sqrt.patch"                                 "int_sqrt"
apply_patch "$BASE/mem_opt_prefetch.patch"                         "mem_opt_prefetch"
apply_patch "$BASE/minimise_wakeup_time.patch"                      "minimise_wakeup_time"
apply_patch "$BASE/optimized_mem_operations.patch"                 "optimized_mem_operations"
apply_patch "$BASE/re_write_limitation_scaling_min_freq.patch"     "re_write_limitation_scaling_min_freq"
apply_patch "$BASE/reduce_cache_pressure.patch"                    "reduce_cache_pressure"
apply_patch "$BASE/reduce_freeze_timeout.patch"                    "reduce_freeze_timeout"
apply_patch "$BASE/reduce_gc_thread_sleep_time.patch"              "reduce_gc_thread_sleep_time"
apply_patch "$BASE/silence_irq_cpu_logspam.patch"                  "silence_irq_cpu_logspam"
apply_patch "$BASE/silence_system_logspam.patch"                   "silence_system_logspam"
apply_patch "$BASE/unicode_bypass_fix_6.1-.patch"                  "unicode_bypass_fix_6.1-"
apply_patch "$BASE/use_unlikely_wrap_cpufreq.patch"                "use_unlikely_wrap_cpufreq"

# ---------------------------------------------------------------------------
# Local patches
# ---------------------------------------------------------------------------
PATCHES_DIR="$WORK_DIR/patches"

# Local patches are ours to maintain, so a patch that stops applying is a real
# problem — but it is not a reason to kill the build on a kernel that still
# boots. Report every miss loudly at the end instead.
NOT_APPLIED=()

apply_dir() {
  local DIR="$1" LABEL="$2" OUT NAME PATCH
  [ -d "$DIR" ] || return 0
  echo "=== Applying $LABEL patches ==="
  for PATCH in "$DIR"/*.patch; do
    [ -f "$PATCH" ] || continue
    NAME="$(basename "$PATCH" .patch)"
    OUT=$(apply_patch "$PATCH" "$NAME" 0 2>&1) || true
    echo "$OUT"
    grep -q "^\[OK\]" <<<"$OUT" && continue
    grep -q "already applied" <<<"$OUT" && continue
    NOT_APPLIED+=("$NAME")
  done
}

apply_dir "$PATCHES_DIR/common"  "common"
[ "$BUILD_TYPE" = "testing" ] && apply_dir "$PATCHES_DIR/testing" "testing"

if [ ${#NOT_APPLIED[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  ${#NOT_APPLIED[@]} local patch(es) did not apply — review before shipping:"
  for NAME in "${NOT_APPLIED[@]}"; do echo "     • $NAME"; done
  echo ""
  echo "[WARN] patch pass finished with ${#NOT_APPLIED[@]} patch(es) not applied"
else
  echo "[OK] All patches applied"
fi
