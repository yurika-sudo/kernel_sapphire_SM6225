#!/usr/bin/env bash
# pack-release.sh — collect everything that goes on the release into ./release_zips
#
# The build job uploads one AnyKernel3 ZIP plus the Seiran Core module ZIP as a
# single artifact; this just unpacks that artifact into the flat directory the
# release action globs.
set -e

mkdir -p ./release_zips
rm -f ./release_zips/*.zip

found=0
while IFS= read -r ZIP; do
  [ -n "$ZIP" ] || continue
  cp "$ZIP" ./release_zips/
  found=1
done < <(find ./artifacts -name "AK3-*.zip" -o -name "seiran-core.zip")

[ "$found" = "1" ] || { echo "[ERROR] no kernel ZIP found in ./artifacts" >&2; exit 1; }

echo "Release assets:"
ls -lh ./release_zips/
