#!/usr/bin/env bash
# build.sh — GKI kernel build (Image + modules)
# env: DEFCONFIG (make target, e.g. gki_defconfig), KERNEL_SRC, WORK_DIR, CLANG_DIR
set -e

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
  -j"$(nproc)"
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
# KMI metadata is baked into utsrelease/version for the GKI ABI.
MAKE_FLAGS+=(BRANCH=android13-5.15-lts KMI_GENERATION=8)

set -o pipefail
mkdir -p "${OUT_DIR}/dist"
cd "$KERNEL_SRC"

LOG="/tmp/build.log"

echo "[GKI] Building defconfig: $DEFCONFIG"
make "${MAKE_FLAGS[@]}" "$DEFCONFIG"

echo "[GKI] Switching to ThinLTO..."
echo "[GKI] Disabling headers install..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -e LTO_CLANG \
  -d LTO_NONE \
  -e LTO_CLANG_THIN \
  -d LTO_CLANG_FULL \
  -e THINLTO \
  -d HEADERS_INSTALL
echo "[GKI] Forcing mq-deadline and stripping BFQ..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -e MQ_IOSCHED_DEADLINE \
  -d IOSCHED_BFQ \
  -d BFQ_GROUP_IOSCHED \
  -d DEFAULT_BFQ \
  -d DEFAULT_NONE \
  -e DEFAULT_DEADLINE \
  --set-str DEFAULT_MQ_IOSCHED "mq-deadline"
echo "[GKI] Re-enforcing TCP_CONG=bbr3..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -e TCP_CONG_ADVANCED \
  -d TCP_CONG_BBR \
  -e TCP_CONG_WESTWOOD \
  -e TCP_CONG_BBR3 \
  --set-str DEFAULT_TCP_CONG "bbr3" \
  -d DEFAULT_BBR \
  -e DEFAULT_BBR3
echo "[GKI] Re-enforcing ZRAM_DEF_COMP=lz4..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -d ZRAM_DEF_COMP_LZORLE \
  -d ZRAM_DEF_COMP_ZSTD \
  -e ZRAM_DEF_COMP_LZ4 \
  -d ZRAM_DEF_COMP_LZO \
  -d CRYPTO_LZO \
  --set-str ZRAM_DEF_COMP "lz4"
echo "[GKI] Forcing Net Scheduler to FQ..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  -e NET_SCH_FQ \
  -d NET_SCH_FQ_CODEL \
  -e NET_SCH_CAKE \
  -e NET_SCH_PIE \
  -e NET_SCH_DEFAULT \
  -e DEFAULT_FQ \
  --set-str DEFAULT_NET_SCH "fq"
make "${MAKE_FLAGS[@]}" olddefconfig  


echo "[GKI] Building Image + modules..."
if ! make "${MAKE_FLAGS[@]}" Image modules 2>&1 | tee "$LOG"; then
  echo "[FAIL] build failed:"
  tail -100 "$LOG"
  exit 1
fi

if [ -f "${OUT_DIR}/dist/arch/arm64/boot/Image" ]; then
  cp "${OUT_DIR}/dist/arch/arm64/boot/Image" "${OUT_DIR}/dist/Image"
  echo "[GKI] Image copied to ${OUT_DIR}/dist/Image"
else
  echo "[FAIL] Image file not found in build directory!"
  exit 1
fi

echo "[GKI] Installing modules..."
MODULES_OUT="${OUT_DIR}/modules"
rm -rf "$MODULES_OUT"
mkdir -p "$MODULES_OUT"
make "${MAKE_FLAGS[@]}" INSTALL_MOD_PATH="$MODULES_OUT" INSTALL_MOD_STRIP=1 modules_install

echo "[GKI] Collecting zram.ko / zsmalloc.ko..."
KO_OUT="${OUT_DIR}/dist/ko"
mkdir -p "$KO_OUT"
ZRAM_KO=$(find "$MODULES_OUT" -name 'zram.ko' | head -1)
ZSMALLOC_KO=$(find "$MODULES_OUT" -name 'zsmalloc.ko' | head -1)
if [ -n "$ZRAM_KO" ]; then
  cp "$ZRAM_KO" "$KO_OUT/zram.ko"
else
  echo "[WARN] zram.ko not found after modules_install — module packaging will be skipped"
fi
if [ -n "$ZSMALLOC_KO" ]; then
  cp "$ZSMALLOC_KO" "$KO_OUT/zsmalloc.ko"
else
  echo "[WARN] zsmalloc.ko not found after modules_install — module packaging will be skipped"
fi
ENCORE_FAS_KO=$(find "$MODULES_OUT" -name 'encore_fas.ko' | head -1)
ATH9K_HTC_KO=$(find "$MODULES_OUT" -name 'ath9k_htc.ko' | head -1)
MAC80211_KO=$(find "$MODULES_OUT" -name 'mac80211.ko' | head -1)
CFG80211_KO=$(find "$MODULES_OUT" -name 'cfg80211.ko' | head -1)
if [ -n "$ENCORE_FAS_KO" ]; then
  cp "$ENCORE_FAS_KO" "$KO_OUT/encore_fas.ko"
  echo "[GKI] Collecting encore_fas.ko..."
fi
if [ -n "$ATH9K_HTC_KO" ]; then
  cp "$ATH9K_HTC_KO" "$KO_OUT/ath9k_htc.ko"
  echo "[GKI] Collecting ath9k_htc.ko..."
fi
if [ -n "$MAC80211_KO" ]; then
  cp "$MAC80211_KO" "$KO_OUT/mac80211.ko"
  echo "[GKI] Collecting mac80211.ko..."
fi
if [ -n "$CFG80211_KO" ]; then
  cp "$CFG80211_KO" "$KO_OUT/cfg80211.ko"
  echo "[GKI] Collecting cfg80211.ko..."
fi
ATH_KO=$(find "$MODULES_OUT" -name 'ath.ko' | head -1)
ATH9K_HW_KO=$(find "$MODULES_OUT" -name 'ath9k_hw.ko' | head -1)
ATH9K_COMMON_KO=$(find "$MODULES_OUT" -name 'ath9k_common.ko' | head -1)
if [ -n "$ATH_KO" ]; then
  cp "$ATH_KO" "$KO_OUT/ath.ko"
  echo "[GKI] Collecting ath.ko..."
fi
if [ -n "$ATH9K_HW_KO" ]; then
  cp "$ATH9K_HW_KO" "$KO_OUT/ath9k_hw.ko"
  echo "[GKI] Collecting ath9k_hw.ko..."
fi
if [ -n "$ATH9K_COMMON_KO" ]; then
  cp "$ATH9K_COMMON_KO" "$KO_OUT/ath9k_common.ko"
  echo "[GKI] Collecting ath9k_common.ko..."
fi

DURATION=$(( $(date +%s) - START ))
echo "✅ Build done in $((DURATION/60))m $((DURATION%60))s"
echo "duration=$DURATION" >> "${GITHUB_OUTPUT:-/dev/null}"
