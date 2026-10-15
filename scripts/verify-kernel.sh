#!/usr/bin/env bash
# verify-kernel.sh — check the built Image is sane, and publish its version string
#
# env: WORK_DIR (Image is expected at $WORK_DIR/out/dist/Image)
#      KERNEL_SRC (optional — used for the utsrelease.h fallback only)
#      GITHUB_ENV (optional)
#
# The version string names the release and the ZIP (pack-zip.sh), so a kernel
# that built but whose version cannot be read is a failure, not a cosmetic one.
set -e

: "${WORK_DIR:?}"

IMAGE="${WORK_DIR}/out/dist/Image"
[ -f "$IMAGE" ] || { echo "[ERROR] Image not found: $IMAGE"; exit 1; }
[ -s "$IMAGE" ] || { echo "[ERROR] Image is empty: $IMAGE"; exit 1; }

# Prefer the string baked into the binary (it proves what was really built) and
# fall back to the build tree when the Image is stripped.
VERSION_FULL=$(strings "$IMAGE" | grep -m1 -E "Linux version [0-9]+" || true)

if [ -z "$VERSION_FULL" ]; then
  for UTS in "${WORK_DIR}/out/dist/include/generated/utsrelease.h" \
             "${WORK_DIR}/out/include/generated/utsrelease.h"; do
    [ -f "$UTS" ] || continue
    UTS_RELEASE=$(grep UTS_RELEASE "$UTS" | cut -d'"' -f2 || true)
    [ -n "$UTS_RELEASE" ] && break
  done
  [ -n "$UTS_RELEASE" ] && VERSION_FULL="Linux version ${UTS_RELEASE}"
fi

if [ -z "$VERSION_FULL" ]; then
  echo "[ERROR] could not read a 'Linux version x.y.z' string from $IMAGE" >&2
  exit 1
fi
echo "Linux version string: $VERSION_FULL"

# "… Linux version 5.15.220-gki-ab1234 (user@host) …" -> "5.15.220-gki-ab1234"
VERSION_CLEAN=$(printf '%s\n' "$VERSION_FULL" | grep -oE 'Linux version [^ ]+' | head -1 | cut -d' ' -f3)
[ -n "$VERSION_CLEAN" ] || VERSION_CLEAN="unknown"

if echo "$VERSION_FULL" | grep -q "dirty"; then
  echo "[ERROR] kernel is dirty — LOCALVERSION was not cleared (Localversion step in build.yml)" >&2
  exit 1
fi

echo "✅ $VERSION_CLEAN"
echo "KERNEL_VERSION=$VERSION_CLEAN" >> "${GITHUB_ENV:-/dev/null}"
echo "$VERSION_CLEAN" > "$WORK_DIR/out/dist/kernel_version.txt"
