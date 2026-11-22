#!/usr/bin/env bash
# check-legacy-patches.sh - compare the GKI-Legacy patch set with common
# Usage: bash scripts/check-legacy-patches.sh [PATCHES_DIR]
# Exits non-zero on any problem.
# POSIX-ish bash, no network.

set -e

if [ "$#" -gt 1 ]; then
  echo "Usage: bash scripts/check-legacy-patches.sh [PATCHES_DIR]" >&2
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

errors=0

# (a) Every common patch not in PENDING.txt and not build-wide skipped must exist
#     in patches/gki-legacy/. Differences are expected for regenerated files.
declare -A PENDING_NAMES=()
pending_count=0
if [ -f "$PENDING_FILE" ]; then
  while IFS= read -r line; do
    name="${line%% - *}"
    name="${name%.patch}"
    PENDING_NAMES["$name"]=1
    pending_count=$((pending_count + 1))
    if [ ! -f "$COMMON_DIR/$name.patch" ]; then
      echo "PENDING NAME NOT IN common: $name.patch"
      errors=$((errors + 1))
    fi
  done < "$PENDING_FILE"
fi

skip_name="rtl8188gu-driver-5.15-sapphire"

for patchfile in "$COMMON_DIR"/*.patch; do
  [ -f "$patchfile" ] || continue
  NAME="$(basename "$patchfile" .patch)"
  if [ -f "$LEGACY_DIR/$NAME.patch" ] && ! cmp -s "$LEGACY_DIR/$NAME.patch" "$patchfile"; then
    echo "[REBUILT] $NAME.patch differs from the common patch (regenerated for 5.15.123)"
  fi
  # Skip pending and build-wide skipped
  if [ -n "${PENDING_NAMES[$NAME]+x}" ] || [ "$NAME" = "$skip_name" ]; then
    continue
  fi
  # Check that the legacy file exists
  if [ ! -f "$LEGACY_DIR/$NAME.patch" ]; then
    echo "MISSING in gki-legacy: $NAME.patch"
    errors=$((errors + 1))
  fi
done

# (b) Every file in patches/gki-legacy/ must have a common counterpart, except
#     for legacy-only compatibility shims named legacy-*.
for patchfile in "$LEGACY_DIR"/*.patch; do
  [ -f "$patchfile" ] || continue
  NAME="$(basename "$patchfile" .patch)"
  if [ ! -f "$COMMON_DIR/$NAME.patch" ]; then
    case "$NAME" in
      legacy-*)
        ;;
      *)
        echo "UNKNOWN in gki-legacy: $NAME.patch (no common counterpart)"
        errors=$((errors + 1))
        ;;
    esac
  fi
done

# Print summary
legacy_count=0
for patchfile in "$LEGACY_DIR"/*.patch; do
  [ -f "$patchfile" ] || continue
  legacy_count=$((legacy_count + 1))
done

echo "legacy set: $legacy_count patches, $pending_count pending"
if [ "$errors" -eq 0 ]; then
  echo "check: no drift detected"
  exit 0
else
  echo "check: $errors drift problem(s) detected"
  exit 1
fi
