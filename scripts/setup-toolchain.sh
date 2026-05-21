#!/usr/bin/env bash
# setup-toolchain.sh — setup build toolchain
# GKI: full AOSP repo sync (includes build system + clang)
# CLO: standalone clang r547379 only
set -e

: "${SOURCE_TYPE:?}"
: "${WORK_DIR:=$GITHUB_WORKSPACE}"

CLANG_VER="r547379"
CLANG_URL="https://github.com/topnotchfreaks/clang/releases/download/v1.0.0/clang-${CLANG_VER}.tar.gz"
CLANG_DIR="${WORK_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VER}"

case "$SOURCE_TYPE" in

  gki)
    echo "[GKI] Syncing AOSP manifest (build system + toolchains) ..."
    cd "$WORK_DIR"
    repo init \
      -u https://android.googlesource.com/kernel/manifest \
      -b common-android13-5.15-lts --depth=1
    repo sync --optimized-fetch --prune --no-clone-bundle --no-tags -j$(nproc --all)
    rm -rf .repo common   # kernel source already in KERNEL_SRC

    # Replace bundled clang with r547379
    mkdir -p "$CLANG_DIR"
    aria2c -x16 -s16 -d /tmp -o clang.tar.gz "$CLANG_URL"
    tar -xzf /tmp/clang.tar.gz -C "$CLANG_DIR"
    rm -f /tmp/clang.tar.gz

    # Remove old/unused clang versions
    for OLD in clang-3289846 clang-r450784e clang-stable; do
      rm -rf "${WORK_DIR}/prebuilts/clang/host/linux-x86/${OLD}" || true
    done

    # Patch build.config to use r547379
    BC="${KERNEL_SRC}/build.config.constants"
    [ -f "$BC" ] && \
      sed -i \
        -e "s/^BRANCH=.*/BRANCH=android13-5.15/" \
        -e "s/^CLANG_VERSION=.*/CLANG_VERSION=${CLANG_VER}/" \
        "$BC" || true

    BC_GKI="${KERNEL_SRC}/build.config.gki"
    [ -f "$BC_GKI" ] && \
      sed -i '/^POST_DEFCONFIG_CMDS="check_defconfig"/d' "$BC_GKI" || true

    echo "CLANG_DIR=$CLANG_DIR" >> "${GITHUB_ENV:-/dev/null}"
    ;;

  clo)
    echo "[CLO] Installing standalone clang ${CLANG_VER} ..."
    mkdir -p "$CLANG_DIR"
    aria2c -x16 -s16 -d /tmp -o clang.tar.gz "$CLANG_URL"
    tar -xzf /tmp/clang.tar.gz -C "$CLANG_DIR"
    rm -f /tmp/clang.tar.gz

    echo "CLANG_DIR=$CLANG_DIR"              >> "${GITHUB_ENV:-/dev/null}"
    echo "PATH=${CLANG_DIR}/bin:$PATH"       >> "${GITHUB_ENV:-/dev/null}"
    ;;

esac

echo "[OK] Toolchain ready: $CLANG_DIR"
