#!/usr/bin/env bash
# clone-source.sh — clone the GKI kernel source
#
# env: KERNEL_SRC (output dir), PINS_FILE (optional, for the branch name)
#
# Single source, single branch: AOSP android13-5.15-lts (GKI). The sublevel
# floats with the branch; sources/source-pins.json records where it was at the
# last "Check Source Updates" run purely so the ccache key rotates on a bump.
set -e

: "${KERNEL_SRC:?KERNEL_SRC must be set (workflow sets it to \$WORK_DIR/kernel_src)}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PINS_FILE="${PINS_FILE:-$SCRIPT_DIR/../sources/source-pins.json}"
GKI_BRANCH="android13-5.15-lts"
if [ -f "$PINS_FILE" ] && command -v jq >/dev/null 2>&1; then
  GKI_BRANCH=$(jq -r '.gki_branch // empty' "$PINS_FILE" 2>/dev/null || true)
  GKI_BRANCH="${GKI_BRANCH:-android13-5.15-lts}"
fi

GKI_REPO="https://android.googlesource.com/kernel/common"
echo "[GKI] Cloning $GKI_BRANCH ..."

mkdir -p "$KERNEL_SRC"
for attempt in 1 2 3; do
  git clone --recursive --branch "$GKI_BRANCH" --depth=1 "$GKI_REPO" "$KERNEL_SRC" && break
  echo "⚠️ Attempt $attempt failed, retrying in 30s..."
  rm -rf "$KERNEL_SRC" && mkdir -p "$KERNEL_SRC"
  sleep 30
done

[ -f "$KERNEL_SRC/Makefile" ] || { echo "[ERROR] kernel source not cloned into $KERNEL_SRC" >&2; exit 1; }

echo "[OK] Source cloned → $KERNEL_SRC"
echo "KERNEL_SRC=$KERNEL_SRC" >> "${GITHUB_ENV:-/dev/null}"
