#!/usr/bin/env bash
# sync-legacy-patches.sh - fill missing GKI-Legacy patches from common
# Usage: bash scripts/sync-legacy-patches.sh [--dry-run] [PATCHES_DIR]
# Never touches patches/common/ or existing files in patches/gki-legacy/.

set -e

DRY_RUN=0
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

if [ "$#" -gt 1 ]; then
  echo "Usage: bash scripts/sync-legacy-patches.sh [--dry-run] [PATCHES_DIR]" >&2
  exit 2
fi

if [ -z "$1" ]; then
  PATCHES_DIR="/root/kernel_sapphire_SM6225"
else
  PATCHES_DIR="$(cd "$1" && pwd)"
fi

COMMON_DIR="$PATCHES_DIR/patches/common"
LEGACY_DIR="$PATCHES_DIR/patches/gki-legacy"
PENDING_FILE="$LEGACY_DIR/PENDING.txt"

# Read pending patch names (first field before the first " - ")
declare -A PENDING_NAMES=()
if [ -f "$PENDING_FILE" ]; then
  while IFS= read -r line; do
    name="${line%% - *}"
    name="${name%.patch}"
    PENDING_NAMES["$name"]=1
  done < "$PENDING_FILE"
fi

# Build-wide skip (rtl8188gu)
SKIP_NAME="rtl8188gu-driver-5.15-sapphire"

added=0
skipped=0
for patchfile in "$COMMON_DIR"/*.patch; do
  [ -f "$patchfile" ] || continue
  NAME="$(basename "$patchfile" .patch)"
  DESTINATION="$LEGACY_DIR/$NAME.patch"

  if [ "$NAME" = "$SKIP_NAME" ]; then
    echo "SKIP build-wide: $NAME.patch"
    skipped=$((skipped + 1))
  elif [ -n "${PENDING_NAMES[$NAME]+x}" ]; then
    echo "SKIP pending: $NAME.patch"
    skipped=$((skipped + 1))
  elif [ -e "$DESTINATION" ] || [ -L "$DESTINATION" ]; then
    echo "SKIP existing: $NAME.patch"
    skipped=$((skipped + 1))
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "ADD (dry-run): $NAME.patch"
    added=$((added + 1))
  else
    cp "$patchfile" "$DESTINATION"
    echo "ADD: $NAME.patch"
    added=$((added + 1))
  fi
done

legacy_count=0
for patchfile in "$LEGACY_DIR"/*.patch; do
  [ -f "$patchfile" ] || continue
  legacy_count=$((legacy_count + 1))
done

if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry run: no files copied"
fi
echo "sync: $added added, $skipped skipped"
echo "legacy set: $legacy_count patches, $(wc -l < "$PENDING_FILE") pending"
