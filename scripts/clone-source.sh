#!/usr/bin/env bash
# clone-source.sh -- clone kernel source
# env: SOURCE_TYPE, KERNEL_SRC (output dir)
set -e

: "${SOURCE_TYPE:?}"
: "${KERNEL_SRC:=$WORK_DIR/kernel_src}"

mkdir -p "$KERNEL_SRC"

case "$SOURCE_TYPE" in

  gki)
    GKI_REPO="https://android.googlesource.com/kernel/common"
    GKI_BRANCH="android13-5.15-lts"
    echo "[GKI] Cloning $GKI_BRANCH ..."
    for attempt in 1 2 3; do
      git clone --recursive --branch "$GKI_BRANCH" "$GKI_REPO" "$KERNEL_SRC" --depth=1 && break
      echo "[WARN] Attempt $attempt failed, retrying in 30s..."
      rm -rf "$KERNEL_SRC" && mkdir -p "$KERNEL_SRC"
      sleep 30
    done
    [ -d "$KERNEL_SRC/.git" ] || { echo "[ERROR] GKI clone failed after 3 attempts"; exit 1; }
    ;;

  gki-legacy)
    GKI_REPO="https://android.googlesource.com/kernel/common"
    GKI_BRANCH="deprecated/android13-5.15-2023-10"
    echo "[GKI-LEGACY] Cloning $GKI_BRANCH (5.15.123) ..."
    for attempt in 1 2 3; do
      git clone --recursive --branch "$GKI_BRANCH" "$GKI_REPO" "$KERNEL_SRC" --depth=1 && break
      echo "[WARN] Attempt $attempt failed, retrying in 30s..."
      rm -rf "$KERNEL_SRC" && mkdir -p "$KERNEL_SRC"
      sleep 30
    done
    [ -d "$KERNEL_SRC/.git" ] || { echo "[ERROR] GKI-Legacy clone failed after 3 attempts"; exit 1; }
    ;;

  *)
    echo "[ERROR] Unknown SOURCE_TYPE: $SOURCE_TYPE (valid: gki, gki-legacy)"
    exit 1
    ;;
esac

echo "[OK] Source cloned: $KERNEL_SRC"
echo "KERNEL_SRC=$KERNEL_SRC" >> "${GITHUB_ENV:-/dev/null}"
