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

# ── 1. WildKernels upstream optimization patches ─────────────────────────────
echo "=== Applying upstream optimization patches ==="
BASE="https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/common"
# Clone for local patches too
git clone --depth=1 https://github.com/WildKernels/kernel_patches \
  "$WORK_DIR/kernel_patches-main" 2>/dev/null || true
KP="$WORK_DIR/kernel_patches-main/common"

apply_patch "$BASE/silence_irq_cpu_logspam.patch"          "silence_irq_cpu_logspam"
apply_patch "$BASE/silence_system_logspam.patch"           "silence_system_logspam"
apply_patch "$BASE/reduce_cache_pressure.patch"            "reduce_cache_pressure"
apply_patch "$BASE/minimise_wakeup_time.patch"             "minimise_wakeup_time"
apply_patch "$BASE/reduce_freeze_timeout.patch"            "reduce_freeze_timeout"
apply_patch "$BASE/avoid_extra_s2idle_wake_attempts.patch" "avoid_extra_s2idle_wake_attempts"
apply_patch "$BASE/adjust_cpu_scan_order.patch"            "adjust_cpu_scan_order"
apply_patch "$KP/disable_cache_hot_buddy.patch"            "disable_cache_hot_buddy"
apply_patch "$BASE/increase_ext4_default_commit_age.patch" "increase_ext4_default_commit_age"

# ── 2. Local patches/common/ (applies to all variants) ──────────────────────
echo "=== Applying local common patches ==="
PATCHES_DIR="$WORK_DIR/patches"
if [ -d "$PATCHES_DIR/common" ]; then
  for PATCH in "$PATCHES_DIR/common"/*.patch; do
    [ -f "$PATCH" ] || continue
    apply_patch "$PATCH" "$(basename "$PATCH" .patch)"
  done
fi

# ── 3. Source-type specific patches ─────────────────────────────────────────
echo "=== Applying $SOURCE_TYPE-specific patches ==="
if [ -d "$PATCHES_DIR/${SOURCE_TYPE}-only" ]; then
  for PATCH in "$PATCHES_DIR/${SOURCE_TYPE}-only"/*.patch; do
    [ -f "$PATCH" ] || continue
    apply_patch "$PATCH" "$(basename "$PATCH" .patch)"
  done
fi

# ── 4. Testing patches (only if build_type=testing) ──────────────────────────
if [ "$BUILD_TYPE" = "testing" ]; then
  echo "=== Applying testing patches ==="
  if [ -d "$PATCHES_DIR/testing" ]; then
    for PATCH in "$PATCHES_DIR/testing"/*.patch; do
      [ -f "$PATCH" ] || continue
      apply_patch "$PATCH" "$(basename "$PATCH" .patch)"
    done
  fi
fi

echo "[OK] All patches applied"
