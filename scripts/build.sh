#!/usr/bin/env bash
# build.sh — dispatch to GKI or CLO build
# env: SOURCE_TYPE, KSU_TYPE, DEFCONFIG, VARIANT, KERNEL_SRC, WORK_DIR, CLANG_DIR
set -e

: "${SOURCE_TYPE:?}"
: "${KERNEL_SRC:?}"
: "${WORK_DIR:?}"
: "${DEFCONFIG:?}"
: "${CLANG_DIR:?}"

OUT_DIR="${WORK_DIR}/out"
START=$(date +%s)

export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-superuseryu}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github}"
export LTO=thin
export KCFLAGS="-pipe -fno-strict-aliasing -Wno-error"

# ─── GKI build via build.sh ──────────────────────────────────────────────────
if [ "$SOURCE_TYPE" = "gki" ]; then
  set -o pipefail

  BUILD_SH="${WORK_DIR}/build/build.sh"
  [ -f "$BUILD_SH" ] || { echo "[ERROR] build/build.sh not found at $BUILD_SH"; ls "$WORK_DIR"; exit 1; }

  export SKIP_ABI_CHECKS=1 SKIP_KMI_CHECK=1

  # GKI build.sh outputs to $OUT_DIR/dist/Image
  if ! {
    KCFLAGS="$KCFLAGS" \
    LLVM_PARALLEL_LINK_JOBS=1 \
    BUILD_CONFIG="${KERNEL_SRC}/build.config.gki.aarch64" \
    OUT_DIR="${WORK_DIR}/out" \
      "$BUILD_SH" -j$(nproc) 2>&1 | tee /tmp/build_gki.log
  }; then
    echo "[FAIL] GKI build failed:"
    grep -E "error:|undefined symbol|ld.lld:" /tmp/build_gki.log | tail -40
    exit 1
  fi

else
  echo "[ERROR] Unknown SOURCE_TYPE: $SOURCE_TYPE"
  exit 1
fi

DURATION=$(( $(date +%s) - START ))
echo "✅ Build done in $((DURATION/60))m $((DURATION%60))s"
echo "duration=$DURATION" >> "${GITHUB_OUTPUT:-/dev/null}"
