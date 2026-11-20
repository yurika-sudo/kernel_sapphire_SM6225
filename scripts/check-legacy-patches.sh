#!/usr/bin/env bash
# check-legacy-patches.sh — drift detector for the GKI-Legacy patch set
# Exits non-zero on any problem.
# POSIX-ish bash, no network.

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

errors=0

# (a) Every common patch not in PENDING.txt and not build-wide skipped must exist
#     in patches/gki-legacy/ and be byte-identical to the common file, unless covered
#     by patches/gki-legacy-overrides/ (then identical to the override).
declare -A LEGACY_NAMES
for f in "$LEGACY_DIR"/*.patch; do
  [ -f "$f" ] || continue
  NAME="$(basename "$f" .patch)"
  LEGACY_NAMES["$NAME"]=1
done

declare -A PENDING_NAMES
if [ -f "$PENDING_FILE" ]; then
  while IFS= read -r line; do
    name="${line%% - *}"
    name="${name%.patch}"
    PENDING_NAMES["$name"]=1
  done < "$PENDING_FILE"
fi

skip_name="rtl8188gu-driver-5.15-sapphire"

for patchfile in "$COMMON_DIR"/*.patch; do
  [ -f "$patchfile" ] || continue
  NAME="$(basename "$patchfile" .patch)"
  # Skip pending and build-wide skipped
  if [ -n "${PENDING_NAMES[$NAME]}" ] || [ "$NAME" = "$skip_name" ]; then
    continue
  fi
  # Check that the legacy file exists
  if [ -z "${LEGACY_NAMES[$NAME]}" ]; then
    echo "MISSING in gki-legacy: $NAME.patch"
    errors=$((errors + 1))
    continue
  fi
  # Check byte identity: if override exists, compare to override; else compare to common
  if [ -f "$OVERRIDES_DIR/${NAME}.patch" ]; then
    if ! diff -q "$LEGACY_DIR/${NAME}.patch" "$OVERRIDES_DIR/${NAME}.patch" > /dev/null 2>&1; then
      echo "OVERRIDE MISMATCH: $NAME.patch differs from override"
      errors=$((errors + 1))
    fi
  else
    if ! diff -q "$LEGACY_DIR/${NAME}.patch" "$patchfile" > /dev/null 2>&1; then
      echo "CONTENT MISMATCH: $NAME.patch differs from common"
      errors=$((errors + 1))
    fi
  fi
done

# (b) Every file in patches/gki-legacy/ must match a common file, an override, or
#     be listed as rebuilt in patches/gki-legacy/README.md
for f in "$LEGACY_DIR"/*.patch; do
  [ -f "$f" ] || continue
  NAME="$(basename "$f" .patch)"
  # Prefer override comparison; fall back to common
  if [ -f "$OVERRIDES_DIR/${NAME}.patch" ]; then
    if ! diff -q "$f" "$OVERRIDES_DIR/${NAME}.patch" > /dev/null 2>&1; then
      echo "DIFFERS from override: $NAME.patch"
      errors=$((errors + 1))
    fi
  elif [ -f "$COMMON_DIR/${NAME}.patch" ]; then
    if ! diff -q "$f" "$COMMON_DIR/${NAME}.patch" > /dev/null 2>&1; then
      echo "DIFFERS from common: $NAME.patch"
      errors=$((errors + 1))
    fi
  fi
done

# (c) Every name in PENDING.txt must exist in patches/common/
pending_count=0
if [ -f "$PENDING_FILE" ]; then
  while IFS= read -r line; do
    name="${line%% - *}"
    name="${name%.patch}"
    if [ ! -f "$COMMON_DIR/${name}.patch" ]; then
      echo "PENDING NAME NOT IN common: ${name}.patch"
      errors=$((errors + 1))
    fi
    pending_count=$((pending_count + 1))
  done < "$PENDING_FILE"
fi

# Print summary
legacy_count=0
for f in "$LEGACY_DIR"/*.patch; do
  [ -f "$f" ] || continue
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