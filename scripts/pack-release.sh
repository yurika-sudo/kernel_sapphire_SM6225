#!/usr/bin/env bash
# pack-release.sh — collect per-variant ZIPs or build proper AIO zip
# env: ZIP_MODE, BUILD_TYPE, DATE_TAG, KERNEL_VERSION
set -e

: "${ZIP_MODE:-per-variant}"
: "${BUILD_TYPE:-stable}"
: "${DATE_TAG:=$(date +'%Y%m%d')}"
: "${KERNEL_VERSION:-5.15.x}"

AK3_REPO="https://github.com/superuseryu/AnyKernel3"
mkdir -p ./release_zips

if [ "$ZIP_MODE" = "aio" ] || [ "$ZIP_MODE" = "both" ]; then
  [ "$BUILD_TYPE" = "testing" ] && SUFFIX="-TESTING" || SUFFIX=""
  AIO_NAME="AnyKernel3_Seiran_ALL_${DATE_TAG}${SUFFIX}.zip"

  echo "[AIO] Building single AK3 zip with all images..."
  git clone --depth=1 "$AK3_REPO" ak3_aio

  for ARTIFACT_ZIP in ./artifacts/*/AnyKernel3_*.zip; do
    [ -f "$ARTIFACT_ZIP" ] || continue
    echo "[AIO] Extracting from: $ARTIFACT_ZIP"
    unzip -o "$ARTIFACT_ZIP" "Image.gki.*" -d ak3_aio/ 2>/dev/null || true
  done

  echo "[AIO] Images collected:"
  ls -lh ak3_aio/Image.gki.* 2>/dev/null || { echo "[ERROR] No named images found in artifacts"; exit 1; }

  cd ak3_aio
  zip -r9 "../release_zips/${AIO_NAME}" * -x .git/*
  cd ..
  rm -rf ak3_aio

  SIZE_MB=$(echo "scale=2; $(stat -c%s "./release_zips/${AIO_NAME}") / 1024 / 1024" | bc | sed 's/^\./0./')
  echo "✅ AIO zip: $AIO_NAME ($SIZE_MB MB)"
fi

if [ "$ZIP_MODE" = "per-variant" ] || [ "$ZIP_MODE" = "both" ]; then
  find ./artifacts -name "AnyKernel3_*.zip" -exec cp {} ./release_zips/ \;
  echo "Collected per-variant ZIPs:"
fi

ls -lh ./release_zips/
