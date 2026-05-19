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
  export SKIP_ABI_CHECKS=1 SKIP_KMI_CHECK=1

  if ! KCFLAGS="$KCFLAGS" LLVM_PARALLEL_LINK_JOBS=1 \
    BUILD_CONFIG="${KERNEL_SRC}/build.config.gki.aarch64" \
    "${WORK_DIR}/build/build.sh" -j$(nproc) 2>&1 | tee /tmp/build_gki.log; then
    echo "[FAIL] GKI build errors:"
    grep -E "undefined symbol|error:|ld.lld" /tmp/build_gki.log | tail -30
    exit 1
  fi

# ─── CLO direct make ─────────────────────────────────────────────────────────
elif [ "$SOURCE_TYPE" = "clo" ]; then
  export PATH="${CLANG_DIR}/bin:$PATH"

  MAKE_FLAGS=(
    -j$(nproc)
    O="$OUT_DIR/dist"
    ARCH=arm64
    SUBARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CC=clang
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    KBUILD_BUILD_USER="$KBUILD_BUILD_USER"
    KBUILD_BUILD_HOST="$KBUILD_BUILD_HOST"
  )

  mkdir -p "$OUT_DIR/dist"
  cd "$KERNEL_SRC"

  echo "[CLO] Building defconfig: $DEFCONFIG"
  make "${MAKE_FLAGS[@]}" "$DEFCONFIG"

  # Merge bengal_GKI.config fragment if provided
  if [ -n "${CLO_FRAGMENT:-}" ] && [ -f "arch/arm64/configs/${CLO_FRAGMENT}" ]; then
    echo "[CLO] Merging fragment: $CLO_FRAGMENT"
    ./scripts/kconfig/merge_config.sh -m -O "$OUT_DIR/dist" \
      "$OUT_DIR/dist/.config" "arch/arm64/configs/${CLO_FRAGMENT}"
    make "${MAKE_FLAGS[@]}" olddefconfig
  fi

  echo "[CLO] Building Image..."
  if ! make "${MAKE_FLAGS[@]}" Image 2>&1 | tee /tmp/build_clo.log; then
    echo "[FAIL] CLO build errors:"
    grep -E "undefined symbol|error:|ld.lld" /tmp/build_clo.log | tail -30
    exit 1
  fi

else
  echo "[ERROR] Unknown SOURCE_TYPE: $SOURCE_TYPE"
  exit 1
fi

DURATION=$(( $(date +%s) - START ))
echo "✅ Build done in $((DURATION/60))m $((DURATION%60))s"
echo "duration=$DURATION" >> "${GITHUB_OUTPUT:-/dev/null}"
