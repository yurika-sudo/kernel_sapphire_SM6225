#!/usr/bin/env bash
# sync-legacy-patches.sh — regenerate patches/gki-legacy/ from common + overrides
# Usage: bash scripts/sync-legacy-patches.sh [PATCHES_DIR]
# Never touches patches/common/.

set -e

if [ -z "$1" ]; then
  PATCHES_DIR="/root/kernel_sapphire_SM6225"
else
  PATCHES_DIR="$(cd "$1" && pwd)"
fi

COMMON_DIR="$PATCHES_DIR/patches/common"
LEGACY_DIR="$PATCHES_DIR/patches/gki-legacy"
OVERRIDES_DIR="$PATCHES_DIR/patches/gki-legacy-overrides"
PENDING_FILE="$PATCHES_DIR/patches/gki-legacy/PENDING.txt"

# Read pending patch names (first field before the first space or dash)
declare -A PENDING_NAMES
if [ -f "$PENDING_FILE" ]; then
  while IFS= read -r line; do
    # Name is the part before the first " - "
    name="${line%% - *}"
    name="${name%.patch}"
    PENDING_NAMES["$name"]=1
  done < "$PENDING_FILE"
fi

# Build-wide skip (rtl8188gu)
SKIP_NAME="rtl8188gu-driver-5.15-sapphire"

# Remove everything from gki-legacy/ (we rebuild from scratch)
rm -f "$LEGACY_DIR"/*.patch

# Copy overrides first (these rebuild specific patches, e.g. the CVE variant)
override_count=0
for patchfile in "$OVERRIDES_DIR"/*.patch; do
  [ -f "$patchfile" ] || continue
  NAME="$(basename "$patchfile" .patch)"
  cp "$patchfile" "$LEGACY_DIR/"
  echo "OVERRIDE: $NAME.patch"
  override_count=$((override_count + 1))
done

# Copy every common patch EXCEPT those in PENDING.txt and the build-wide skip
common_count=0
common_skipped=0
for patchfile in "$COMMON_DIR"/*.patch; do
  [ -f "$patchfile" ] || continue
  NAME="$(basename "$patchfile" .patch)"
  common_count=$((common_count + 1))
  # Skip if pending or build-wide skipped
  if [ -n "${PENDING_NAMES[$NAME]}" ] || [ "$NAME" = "$SKIP_NAME" ]; then
    echo "SKIP common: $NAME.patch"
    common_skipped=$((common_skipped + 1))
    continue
  fi
  # Skip if an override already covers this patch name
  if [ -f "$OVERRIDES_DIR/${NAME}.patch" ]; then
    echo "SKIP common (overridden): $NAME.patch"
    continue
  fi
  cp "$patchfile" "$LEGACY_DIR/"
  echo "COPY common: $NAME.patch"
done

echo "legacy set: $common_count patches, $(wc -l < "$PENDING_FILE") pending"