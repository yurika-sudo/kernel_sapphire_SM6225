#!/usr/bin/env bash
# clone-source.sh — clone kernel source (GKI or CLO)
# env: SOURCE_TYPE, KSU_TYPE, KERNEL_SRC (output dir)
set -e

: "${SOURCE_TYPE:?}"
: "${KERNEL_SRC:=$WORK_DIR/kernel_src}"

mkdir -p "$KERNEL_SRC"

case "$SOURCE_TYPE" in

  gki)
    GKI_REPO="https://android.googlesource.com/kernel/common"
    GKI_BRANCH="android13-5.15-lts"
    echo "[GKI] Cloning $GKI_BRANCH ..."
    git clone --recursive --branch "$GKI_BRANCH" "$GKI_REPO" "$KERNEL_SRC" --depth=1
    ;;

  clo)
    CLO_REPO="https://git.codelinaro.org/clo/la/kernel/msm-5.15"
    CLO_BRANCH="kernel.lnx.5.15.r59-rel"
    echo "[CLO] Cloning $CLO_BRANCH ..."
    git clone --recursive --branch "$CLO_BRANCH" "$CLO_REPO" "$KERNEL_SRC" --depth=1
    ;;

  *)
    echo "[ERROR] Unknown source type: $SOURCE_TYPE"
    exit 1
    ;;
esac

echo "[OK] Source cloned → $KERNEL_SRC"
echo "KERNEL_SRC=$KERNEL_SRC" >> "${GITHUB_ENV:-/dev/null}"
