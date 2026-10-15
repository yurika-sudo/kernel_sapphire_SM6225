#!/usr/bin/env bash
# pack-zip.sh — pack the AnyKernel3 flashable ZIP for this build
#
# env: WORK_DIR, BUILD_TYPE (stable | testing)
set -e

: "${WORK_DIR:?}"
: "${BUILD_TYPE:-stable}"

AK3_REPO="https://github.com/superuseryu/AnyKernel3"
IMAGE="${WORK_DIR}/out/dist/Image"

[ -f "$IMAGE" ] || { echo "[ERROR] Image not found: $IMAGE" >&2; exit 1; }

# Read kernel sublevel from the build output — X.Y.Z only, drop the uname suffix
VERSION_FILE="${WORK_DIR}/out/dist/kernel_version.txt"
_raw=$([ -f "$VERSION_FILE" ] && tr -d '[:space:]' < "$VERSION_FILE" || echo "5.15.x")
KERNEL_VERSION=$(echo "$_raw" | grep -oP '^\d+\.\d+\.\d+' || echo "$_raw")

[ "$BUILD_TYPE" = "testing" ] && SUFFIX="-testing" || SUFFIX=""
ZIP_NAME="AK3-Seiran-GKI-${KERNEL_VERSION}-$(date +%Y-%m)${SUFFIX}.zip"

cd "$WORK_DIR"
rm -rf ak3_tmp
git clone --depth=1 "$AK3_REPO" ak3_tmp
[ -d "${GITHUB_WORKSPACE}/anykernel/ramdisk" ] && cp -r "${GITHUB_WORKSPACE}/anykernel/ramdisk/." "ak3_tmp/ramdisk/"

cp "$IMAGE" "ak3_tmp/Image"

# Bundle the modules that CONFIG_ZRAM=m / ath9k produce — the Image alone can't
# carry them. Missing ones are skipped with a warning, not fatal.
KO_DIR="${WORK_DIR}/out/dist/ko"
if [ -f "${KO_DIR}/zram.ko" ] && [ -f "${KO_DIR}/zsmalloc.ko" ]; then
  mkdir -p "ak3_tmp/modules/system/lib/modules"
  cp "${KO_DIR}/zram.ko"     "ak3_tmp/modules/system/lib/modules/"
  cp "${KO_DIR}/zsmalloc.ko" "ak3_tmp/modules/system/lib/modules/"
  if [ -f "${KO_DIR}/encore_fas.ko" ]; then
    cp "${KO_DIR}/encore_fas.ko" "ak3_tmp/modules/system/lib/modules/"
    echo "[INFO] encore_fas.ko bundled"
  fi
  echo "[INFO] zram modules bundled into zip"
else
  echo "[WARN] zram.ko/zsmalloc.ko not found in ${KO_DIR} — skipping module bundle"
fi

cd ak3_tmp
zip -r9 "../${ZIP_NAME}" * -x .git/*
cd ..
rm -rf ak3_tmp

SIZE_MB=$(echo "scale=2; $(stat -c%s "$ZIP_NAME") / 1024 / 1024" | bc | sed 's/^\./0./')
echo "✅ Packed: $ZIP_NAME ($SIZE_MB MB)"

echo "ZIP_NAME=$ZIP_NAME"     >> "${GITHUB_ENV:-/dev/null}"
echo "ZIP_SIZE_MB=$SIZE_MB"   >> "${GITHUB_ENV:-/dev/null}"
