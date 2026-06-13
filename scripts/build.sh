#!/usr/bin/env bash
# build.sh — GKI direct make build
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

# ─── GKI direct make ─────────────────────────────────────────────────────────
if [ "$SOURCE_TYPE" = "gki" ]; then
  set -o pipefail

  export PATH="${CLANG_DIR}/bin:$PATH"

  MAKE_FLAGS=(
    -j$(nproc)
    O="${OUT_DIR}/dist"
    ARCH=arm64
    SUBARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CC="ccache clang"
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
    BRANCH=android13-5.15-lts
    KMI_GENERATION=8
    KCFLAGS="-pipe -fno-strict-aliasing -Wno-error"
    LTO=thin
    LLVM_PARALLEL_LINK_JOBS=1
  )

  mkdir -p "${OUT_DIR}/dist"
  cd "$KERNEL_SRC"



  echo "[GKI] Building defconfig: $DEFCONFIG"
  make "${MAKE_FLAGS[@]}" "$DEFCONFIG"

  echo "[GKI] Building Image..."
  if ! make "${MAKE_FLAGS[@]}" Image 2>&1 | tee /tmp/build_gki.log; then
    echo "[FAIL] GKI build failed:"
    tail -60 /tmp/build_gki.log
    exit 1
  fi

  cp "${OUT_DIR}/dist/arch/arm64/boot/Image" "${OUT_DIR}/dist/Image"
  echo "[GKI] Image copied to ${OUT_DIR}/dist/Image"


elif [ "$SOURCE_TYPE" = "clo" ]; then
  set -o pipefail

  export PATH="${CLANG_DIR}/bin:$PATH"

  MAKE_FLAGS=(
    -j$(nproc)
    O="${OUT_DIR}/dist"
    ARCH=arm64
    SUBARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CC="ccache clang"
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
    KCFLAGS="-pipe -fno-strict-aliasing -Wno-error"
    LTO=thin
    LLVM_PARALLEL_LINK_JOBS=1
  )

  mkdir -p "${OUT_DIR}/dist"
  cd "$KERNEL_SRC"

  echo "[CLO] Building defconfig: $DEFCONFIG"
  make "${MAKE_FLAGS[@]}" "$DEFCONFIG"

  # Merge vendor config fragment if provided (e.g. vendor/bengal_GKI.config)
  if [ -n "$CLO_FRAGMENT" ] && [ -f "arch/arm64/configs/${CLO_FRAGMENT}" ]; then
    echo "[CLO] Merging fragment: $CLO_FRAGMENT"
    KCONFIG_CONFIG="${OUT_DIR}/dist/.config" \
      scripts/kconfig/merge_config.sh -m -q \
      "${OUT_DIR}/dist/.config" \
      "arch/arm64/configs/${CLO_FRAGMENT}"
    make "${MAKE_FLAGS[@]}" olddefconfig
    echo "[CLO] Fragment merged"

    # Re-enforce ZRAM LZ4 — CLO fragment may override it back to lzo-rle
    echo "[CLO] Re-enforcing ZRAM_DEF_COMP=lz4 after fragment merge"
    ./scripts/config --file "${OUT_DIR}/dist/.config" \
      -d ZRAM_DEF_COMP_LZORLE \
      -d ZRAM_DEF_COMP_ZSTD \
      -e ZRAM_DEF_COMP_LZ4 \
      -d ZRAM_DEF_COMP_LZO \
      --set-str ZRAM_DEF_COMP "lz4"
    make "${MAKE_FLAGS[@]}" olddefconfig
  fi

  echo "[CLO] Building Image..."
  if ! make "${MAKE_FLAGS[@]}" Image 2>&1 | tee /tmp/build_clo.log; then
    echo "[FAIL] CLO build failed:"
    tail -60 /tmp/build_clo.log
    exit 1
  fi

  cp "${OUT_DIR}/dist/arch/arm64/boot/Image" "${OUT_DIR}/dist/Image"
  echo "[CLO] Image copied to ${OUT_DIR}/dist/Image"

else
  echo "[ERROR] Unknown SOURCE_TYPE: $SOURCE_TYPE"
  exit 1
fi

DURATION=$(( $(date +%s) - START ))
echo "✅ Build done in $((DURATION/60))m $((DURATION%60))s"
echo "duration=$DURATION" >> "${GITHUB_OUTPUT:-/dev/null}"
