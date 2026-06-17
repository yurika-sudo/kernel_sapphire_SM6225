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
    for attempt in 1 2 3; do
      git clone --recursive --branch "$GKI_BRANCH" "$GKI_REPO" "$KERNEL_SRC" --depth=1 && break
      echo "⚠️ Attempt $attempt failed, retrying in 30s..."
      rm -rf "$KERNEL_SRC" && mkdir -p "$KERNEL_SRC"
      sleep 30
    done
    ;;

  clo)
    CLO_REPO="https://git.codelinaro.org/clo/la/kernel/msm-5.15"
    CLO_BRANCH="kernel.lnx.5.15.r1-rel"
    if [ "${CLO_CACHE_HIT}" = "true" ] && [ -d "$KERNEL_SRC/.git" ]; then
      echo "[CLO] Cache hit — fetching delta only..."
      git -C "$KERNEL_SRC" fetch origin --depth=1 "$CLO_BRANCH"
      git -C "$KERNEL_SRC" reset --hard FETCH_HEAD
    else
      echo "[CLO] Cloning $CLO_BRANCH ..."
      for attempt in 1 2 3; do
        git clone --recursive --branch "$CLO_BRANCH" "$CLO_REPO" "$KERNEL_SRC" --depth=1 && break
        echo "⚠️ Attempt $attempt failed, retrying in 30s..."
        rm -rf "$KERNEL_SRC" && mkdir -p "$KERNEL_SRC"
        sleep 30
      done
    fi
    ;;

  *)
    echo "[ERROR] Unknown source type: $SOURCE_TYPE"
    exit 1
    ;;
esac

echo "[OK] Source cloned → $KERNEL_SRC"
echo "KERNEL_SRC=$KERNEL_SRC" >> "${GITHUB_ENV:-/dev/null}"
