#!/usr/bin/env bash
# build.sh — unified GKI/CLO kernel build
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
export PATH="${CLANG_DIR}/bin:$PATH"

if command -v ccache &>/dev/null; then _CC="ccache clang"; else _CC="clang"; fi

MAKE_FLAGS=(
  -j$(nproc)
  O="${OUT_DIR}/dist"
  ARCH=arm64
  SUBARCH=arm64
  LLVM=1
  LLVM_IAS=1
  CC="$_CC"
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
  KCFLAGS="-pipe -fno-strict-aliasing -Wno-error -Wno-unknown-warning-option -Wno-array-bounds -Wno-stringop-overflow -Wno-mismatched-function-types"
  LLVM_PARALLEL_LINK_JOBS=2
)
[[ "$SOURCE_TYPE" == gki* ]] && MAKE_FLAGS+=(BRANCH=android13-5.15-lts KMI_GENERATION=8)

set -o pipefail
mkdir -p "${OUT_DIR}/dist"
cd "$KERNEL_SRC"

LOG="/tmp/build_${SOURCE_TYPE}.log"

echo "[${SOURCE_TYPE^^}] Building defconfig: $DEFCONFIG"
make "${MAKE_FLAGS[@]}" "$DEFCONFIG"

echo "[${SOURCE_TYPE^^}] Switching to ThinLTO..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  --disable LTO_NONE \
  --disable LTO_CLANG_FULL \
  --enable  LTO_CLANG_THIN
make "${MAKE_FLAGS[@]}" olddefconfig

# CLO-only: merge vendor fragment then re-enforce overrides
if [ "$SOURCE_TYPE" = "clo" ] && [ -n "${CLO_FRAGMENT:-}" ] && \
   [ -f "arch/arm64/configs/${CLO_FRAGMENT}" ]; then
  echo "[CLO] Merging fragment: $CLO_FRAGMENT"
  KCONFIG_CONFIG="${OUT_DIR}/dist/.config" \
    scripts/kconfig/merge_config.sh -m \
    "${OUT_DIR}/dist/.config" \
    "arch/arm64/configs/${CLO_FRAGMENT}"
  make "${MAKE_FLAGS[@]}" olddefconfig
  echo "[CLO] Re-enforcing ZRAM_DEF_COMP=lz4 after fragment merge"
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -d ZRAM_DEF_COMP_LZORLE \
    -d ZRAM_DEF_COMP_ZSTD \
    -e ZRAM_DEF_COMP_LZ4 \
    -d ZRAM_DEF_COMP_LZO \
    --set-str ZRAM_DEF_COMP "lz4"
  echo "[CLO] Re-enforcing TCP_CONG=westwood after fragment merge"
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -d TCP_CONG_BBR \
    -e TCP_CONG_WESTWOOD \
    --set-str DEFAULT_TCP_CONG "westwood" \
    -d DEFAULT_BBR \
    -e DEFAULT_WESTWOOD
  make "${MAKE_FLAGS[@]}" olddefconfig
   echo "[${SOURCE_TYPE^^}] Disabling debug warnings and protecting BTF..."
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    --set-val CONFIG_PANIC_ON_OOPS_VALUE 0 \
    -d SCHED_STACK_END_CHECK \
    -d DEBUG_MISC \
    -d DEBUG_KERNEL \
    -d DEBUG_LIST \
    -e DEBUG_INFO \
    -e DEBUG_INFO_DWARF4 \
    -e DEBUG_INFO_BTF \
    -e DEBUG_INFO_BTF_MODULES
   make "${MAKE_FLAGS[@]}" olddefconfig
 fi

echo "[${SOURCE_TYPE^^}] Building Image..."
if ! make "${MAKE_FLAGS[@]}" Image 2>&1 | tee "$LOG"; then
  echo "[FAIL] ${SOURCE_TYPE^^} build failed:"
  tail -100 "$LOG"
  exit 1
fi

cp "${OUT_DIR}/dist/arch/arm64/boot/Image" "${OUT_DIR}/dist/Image"
echo "[${SOURCE_TYPE^^}] Image copied to ${OUT_DIR}/dist/Image"

DURATION=$(( $(date +%s) - START ))
echo "✅ Build done in $((DURATION/60))m $((DURATION%60))s"
echo "duration=$DURATION" >> "${GITHUB_OUTPUT:-/dev/null}"
