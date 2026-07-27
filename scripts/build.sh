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
  OBJSIZE=llvm-size
  READELF=llvm-readelf
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  KBUILD_BUILD_USER="$KBUILD_BUILD_USER"
  KBUILD_BUILD_HOST="$KBUILD_BUILD_HOST"
  KCFLAGS="-pipe -fno-strict-aliasing -fno-common -Wno-error -Wno-unknown-warning-option -Wno-array-bounds -Wno-stringop-overflow -Wno-mismatched-function-types -Wno-unused-variable -Wno-misleading-indentation -Wno-incompatible-function-pointer-types"
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
  -e LTO_CLANG \
  -d LTO_NONE \
  -e LTO_CLANG_THIN \
  -d LTO_CLANG_FULL \
  -e THINLTO
echo "[${SOURCE_TYPE^^}] Forcing mq-deadline and stripping BFQ..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -e MQ_IOSCHED_DEADLINE \
  -d IOSCHED_BFQ \
  -d BFQ_GROUP_IOSCHED \
  -d DEFAULT_BFQ \
  -d DEFAULT_NONE \
  -e DEFAULT_DEADLINE \
  --set-str DEFAULT_MQ_IOSCHED "mq-deadline"
echo "[${SOURCE_TYPE^^}] Re-enforcing TCP_CONG=bbr3..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -e TCP_CONG_ADVANCED \
  -d TCP_CONG_BBR \
  -e TCP_CONG_WESTWOOD \
  -e TCP_CONG_BBR3 \
  --set-str DEFAULT_TCP_CONG "bbr3" \
  -d DEFAULT_BBR \
  -e DEFAULT_BBR3
echo "[${SOURCE_TYPE^^}] Re-enforcing ZRAM_DEF_COMP=lz4..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -d ZRAM_DEF_COMP_LZORLE \
  -d ZRAM_DEF_COMP_ZSTD \
  -e ZRAM_DEF_COMP_LZ4 \
  -d ZRAM_DEF_COMP_LZO \
  -d CRYPTO_LZO \
  --set-str ZRAM_DEF_COMP "lz4"
echo "[${SOURCE_TYPE^^}] Forcing Net Scheduler to FQ..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -e NET_SCH_FQ \
  -d NET_SCH_FQ_CODEL \
  -e NET_SCH_CAKE \
  -e NET_SCH_PIE \
  -e NET_SCH_DEFAULT \
  -e DEFAULT_FQ \
  --set-str DEFAULT_NET_SCH "fq"
make "${MAKE_FLAGS[@]}" olddefconfig  

if [ -n "${CLO_FRAGMENT:-}" ]; then
  echo "[${SOURCE_TYPE^^}] Merging fragment(s): $CLO_FRAGMENT"
  FRAG_PATHS=()
  for f in $CLO_FRAGMENT; do
    FRAG_PATHS+=("arch/arm64/configs/$f")
  done
  KCONFIG_CONFIG="${OUT_DIR}/dist/.config" \
    scripts/kconfig/merge_config.sh -m \
    "${OUT_DIR}/dist/.config" \
    "${FRAG_PATHS[@]}"
  make "${MAKE_FLAGS[@]}" olddefconfig
  echo "[CLO] Re-enforcing ZRAM_DEF_COMP=lz4 after fragment merge"
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -d ZRAM_DEF_COMP_LZORLE \
    -d ZRAM_DEF_COMP_ZSTD \
    -e ZRAM_DEF_COMP_LZ4 \
    -d ZRAM_DEF_COMP_LZO \
    -d CRYPTO_LZO \
    --set-str ZRAM_DEF_COMP "lz4"
  echo "[CLO] Re-enforcing TCP_CONG=bbr3 after fragment merge"
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -e TCP_CONG_ADVANCED \
    -d TCP_CONG_BBR \
    -e TCP_CONG_WESTWOOD \
    -e TCP_CONG_BBR3 \
    --set-str DEFAULT_TCP_CONG "bbr3" \
    -d DEFAULT_BBR \
    -e DEFAULT_BBR3
  echo "[CLO] Re-enforcing mq-deadline I/O scheduler after fragment merge"
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -e MQ_IOSCHED_DEADLINE \
    -d IOSCHED_BFQ \
    -d BFQ_GROUP_IOSCHED \
    -e DEFAULT_DEADLINE \
    -d DEFAULT_BFQ \
    -d DEFAULT_NONE \
    --set-str DEFAULT_MQ_IOSCHED "mq-deadline"
  echo "[CLO] Forcing Net Scheduler to FQ and TCP Advanced..."
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -e NET_SCH_FQ \
    -d NET_SCH_FQ_CODEL \
    -e NET_SCH_CAKE \
    -e NET_SCH_PIE \
    -e NET_SCH_DEFAULT \
    -e DEFAULT_FQ \
    --set-str DEFAULT_NET_SCH "fq"
  make "${MAKE_FLAGS[@]}" olddefconfig
 fi

echo "[${SOURCE_TYPE^^}] Building Image..."
if ! make "${MAKE_FLAGS[@]}" Image 2>&1 | tee "$LOG"; then
  echo "[FAIL] ${SOURCE_TYPE^^} build failed:"
  tail -100 "$LOG"
  exit 1
fi

if [ -f "${OUT_DIR}/dist/arch/arm64/boot/Image" ]; then
  cp "${OUT_DIR}/dist/arch/arm64/boot/Image" "${OUT_DIR}/dist/Image"
  echo "[${SOURCE_TYPE^^}] Image copied to ${OUT_DIR}/dist/Image"
else
  echo "[FAIL] Image file not found in build directory!"
  exit 1
fi

DURATION=$(( $(date +%s) - START ))
echo "✅ Build done in $((DURATION/60))m $((DURATION%60))s"
echo "duration=$DURATION" >> "${GITHUB_OUTPUT:-/dev/null}"
