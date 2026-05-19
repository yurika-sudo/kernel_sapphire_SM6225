#!/usr/bin/env bash
# pack-release.sh — collect per-variant ZIPs, optionally bundle into AIO
# env: ZIP_MODE, BUILD_TYPE, DATE_TAG, KERNEL_VERSION
set -e

: "${ZIP_MODE:-per-variant}"
: "${BUILD_TYPE:-stable}"
: "${DATE_TAG:=$(date +'%Y%m%d')}"
: "${KERNEL_VERSION:-5.15.x}"

mkdir -p ./release_zips
find ./artifacts -name "AnyKernel3_*.zip" -exec cp {} ./release_zips/ \;
echo "Collected ZIPs:"
ls -lh ./release_zips/

if [ "$ZIP_MODE" = "aio" ]; then
  [ "$BUILD_TYPE" = "testing" ] && SUFFIX="-TESTING" || SUFFIX=""
  AIO_NAME="AnyKernel3_Sapphire_ALL_${DATE_TAG}${SUFFIX}.zip"

  # Bundle all variant zips into one AIO archive
  zip -r9 "./release_zips/${AIO_NAME}" ./release_zips/AnyKernel3_*.zip
  # Remove individual zips from release_zips (AIO only)
  find ./release_zips -name "AnyKernel3_*.zip" ! -name "$AIO_NAME" -delete
  echo "✅ AIO bundle: $AIO_NAME"
fi

ls -lh ./release_zips/
