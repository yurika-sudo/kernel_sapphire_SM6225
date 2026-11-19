#!/usr/bin/env bash
# apply-patches.sh — apply patches from patches/ folder + WildKernels patches
# env: SOURCE_TYPE, KSU_TYPE, BUILD_TYPE, KERNEL_SRC, DEFCONFIG
set -e

: "${KERNEL_SRC:?}"
: "${SOURCE_TYPE:?}"
: "${KSU_TYPE:?}"
: "${BUILD_TYPE:-stable}"
: "${WORK_DIR:=$GITHUB_WORKSPACE}"

source /tmp/apply_patch.sh
cd "$KERNEL_SRC"

# GKI-Legacy now applies patches/common from patches/common/,
# with patches/gki-legacy-only/ providing regenerated legacy variants
# for patches that do not apply on 5.15.123. Testing patches remain opt-in.

# WildKernels patches
echo "=== Applying upstream optimization patches ==="
BASE="https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/common"

apply_patch "$BASE/ntsync/ntsync_base.patch"                       "ntsync_base"
apply_patch "$BASE/ntsync/ntsync_compat_android13-5.15.patch"      "ntsync_compat_android13-5.15"
python3 "$WORK_DIR/scripts/ntsync-compat.py" "$KERNEL_SRC"
apply_patch "$BASE/IPv6_NAT_FIX.patch"                             "IPv6_NAT_FIX"
apply_patch "$BASE/add_limitation_scaling_min_freq.patch"          "add_limitation_scaling_min_freq"
apply_patch "$BASE/add_timeout_wakelocks_globally.patch"           "add_timeout_wakelocks_globally"
apply_patch "$BASE/adjust_cpu_scan_order.patch"                    "adjust_cpu_scan_order"
apply_patch "$BASE/avoid_extra_s2idle_wake_attempts.patch"         "avoid_extra_s2idle_wake_attempts"
apply_patch "$BASE/clear_page_16bytes_align.patch"                 "clear_page_16bytes_align"
apply_patch "$BASE/disable_cache_hot_buddy.patch"                  "disable_cache_hot_buddy"
apply_patch "$BASE/f2fs_reduce_congestion.patch"                   "f2fs_reduce_congestion"
apply_patch "$BASE/file_struct_8bytes_align.patch"                 "file_struct_8bytes_align"
apply_patch "$BASE/increase_ext4_default_commit_age.patch"         "increase_ext4_default_commit_age"
apply_patch "$BASE/increase_sk_mem_packets.patch"                  "increase_sk_mem_packets"
apply_patch "$BASE/int_sqrt.patch"                                 "int_sqrt"
apply_patch "$BASE/mem_opt_prefetch.patch"                         "mem_opt_prefetch"
apply_patch "$BASE/optimized_mem_operations.patch"                 "optimized_mem_operations"
apply_patch "$BASE/re_write_limitation_scaling_min_freq.patch"     "re_write_limitation_scaling_min_freq"
apply_patch "$BASE/reduce_cache_pressure.patch"                    "reduce_cache_pressure"
apply_patch "$BASE/reduce_freeze_timeout.patch"                    "reduce_freeze_timeout"
apply_patch "$BASE/reduce_gc_thread_sleep_time.patch"              "reduce_gc_thread_sleep_time"
apply_patch "$BASE/silence_irq_cpu_logspam.patch"                  "silence_irq_cpu_logspam"
apply_patch "$BASE/silence_system_logspam.patch"                   "silence_system_logspam"
apply_patch "$BASE/unicode_bypass_fix_6.1-.patch"                  "unicode_bypass_fix_6.1-"
apply_patch "$BASE/use_unlikely_wrap_cpufreq.patch"                "use_unlikely_wrap_cpufreq"

# Local common patches
echo "=== Applying local common patches ==="
PATCHES_DIR="$WORK_DIR/patches"
FALLBACK_DIR=""
if [ "$SOURCE_TYPE" = "gki-compat" ]; then
  FALLBACK_DIR="$PATCHES_DIR/gki-compat-only"
elif [ "$SOURCE_TYPE" = "gki-legacy" ]; then
  FALLBACK_DIR="$PATCHES_DIR/gki-legacy-only"
fi
if [ -d "$PATCHES_DIR/common" ]; then
  # Skipped by default: the RTL8188GU wifi dongle driver is not needed for
  # the target devices and the patch is very large, so it only slows the build.
  SKIP_PATCHES="rtl8188gu-driver-5.15-sapphire"
  for PATCH in "$PATCHES_DIR/common"/*.patch; do
    [ -f "$PATCH" ] || continue
    NAME="$(basename "$PATCH" .patch)"
    # Skip optional large driver patches not needed for target devices.
    if echo "$SKIP_PATCHES" | grep -qw "$NAME"; then
      echo "[SKIP-BUILD] $NAME - disabled (large optional driver)"
      continue
    fi
    # For gki-legacy: if a legacy-only variant exists, use it instead of the
    # common patch (common version is not applied at all). Otherwise fall
    # through to try the common patch below.
    if [ "$SOURCE_TYPE" = "gki-legacy" ] && [ -f "$FALLBACK_DIR/${NAME}.patch" ]; then
      echo "[LEGACY-ONLY] $NAME — using gki-legacy-only variant, skipping common"
      apply_patch "$FALLBACK_DIR/${NAME}.patch" "$NAME"
      continue
    fi
    # Try common patch first; on failure look for a
    # source-specific fallback before giving up.
    if ! patch -p1 --dry-run --forward --quiet < "$PATCH" 2>/dev/null; then
      if patch -p1 --dry-run --reverse --quiet < "$PATCH" 2>/dev/null; then
        echo "[SKIP] $NAME — already applied"
      elif [ -n "$FALLBACK_DIR" ] && [ -f "$FALLBACK_DIR/${NAME}.patch" ]; then
        echo "[FALLBACK] $NAME — common failed, trying ${SOURCE_TYPE}-only fallback"
        apply_patch "$FALLBACK_DIR/${NAME}.patch" "$NAME"
      else
        echo "[SKIP] $NAME — not applicable to ${SOURCE_TYPE} (no fallback)"
      fi
      continue
    fi
    apply_patch "$PATCH" "$NAME"
  done
fi

# Source-type patches
echo "=== Applying $SOURCE_TYPE-specific patches ==="
if [ -d "$PATCHES_DIR/${SOURCE_TYPE}-only" ]; then
  for PATCH in "$PATCHES_DIR/${SOURCE_TYPE}-only"/*.patch; do
    [ -f "$PATCH" ] || continue
    apply_patch "$PATCH" "$(basename "$PATCH" .patch)"
  done
fi

# Testing patches
if [ "$BUILD_TYPE" = "testing" ] && [ "$SOURCE_TYPE" != "gki-legacy" ]; then
  echo "=== Applying testing patches ==="
  if [ -d "$PATCHES_DIR/testing" ]; then
    for PATCH in "$PATCHES_DIR/testing"/*.patch; do
      [ -f "$PATCH" ] || continue
      apply_patch "$PATCH" "$(basename "$PATCH" .patch)"
    done
  fi
fi

echo "[OK] All patches applied"
