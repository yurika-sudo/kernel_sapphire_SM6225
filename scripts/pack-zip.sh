#!/usr/bin/env bash
# pack-zip.sh — pack AnyKernel3 zip per variant
# env: ZIP_PREFIX, KSU_TYPE, BUILD_TYPE, WORK_DIR, BUILD_DATE
set -e

: "${ZIP_PREFIX:?}"
: "${KSU_TYPE:?}"
: "${WORK_DIR:?}"
: "${BUILD_TYPE:-stable}"
: "${BUILD_DATE:=$(date +'%Y%m%d')}"

AK3_REPO="https://github.com/superuseryu/AnyKernel3"
IMAGE="${WORK_DIR}/out/dist/Image"

[ -f "$IMAGE" ] || { echo "[ERROR] Image not found: $IMAGE"; exit 1; }

[ "$BUILD_TYPE" = "testing" ] && SUFFIX="-TESTING" || SUFFIX=""
ZIP_NAME="AnyKernel3_${ZIP_PREFIX}_${BUILD_DATE}${SUFFIX}.zip"

# Named image used by AIO pack-release.sh when extracting
case "$KSU_TYPE" in
  wild) IMAGE_NAME="Image.gki.ksu"  ;;
  suki) IMAGE_NAME="Image.gki.suki" ;;
  none) IMAGE_NAME="Image.gki.noksu";;
  *)    IMAGE_NAME="Image"          ;;
esac

cd "$WORK_DIR"
git clone --depth=1 "$AK3_REPO" ak3_tmp

# Per-variant ZIP: only Image (for flashing) — no named copy to keep size lean
cp "$IMAGE" "ak3_tmp/Image"

cd ak3_tmp
zip -r9 "../${ZIP_NAME}" * -x .git/*
cd ..
rm -rf ak3_tmp

SIZE_MB=$(echo "scale=2; $(stat -c%s "$ZIP_NAME") / 1024 / 1024" | bc | sed 's/^\./0./')
echo "✅ Packed: $ZIP_NAME ($SIZE_MB MB)"

echo "ZIP_NAME=$ZIP_NAME"         >> "${GITHUB_ENV:-/dev/null}"
echo "ZIP_SIZE_MB=$SIZE_MB"       >> "${GITHUB_ENV:-/dev/null}"
echo "DATE_TAG=$BUILD_DATE"       >> "${GITHUB_ENV:-/dev/null}"
echo "IMAGE_NAME=$IMAGE_NAME"     >> "${GITHUB_ENV:-/dev/null}"
