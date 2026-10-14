#!/usr/bin/env bash
# setup-toolchain.sh — Neutron Clang for GKI, ZyC-14 for CLO
# env: WORK_DIR, KERNEL_SRC, SOURCE_TYPE
set -e

: "${WORK_DIR:=$GITHUB_WORKSPACE}"
: "${KERNEL_SRC:?}"
: "${SOURCE_TYPE:?}"

if [[ "$SOURCE_TYPE" == gki* ]]; then
  CLANG_VER="06092026"
  CLANG_URL="https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/${CLANG_VER}/neutron-clang-${CLANG_VER}.tar.zst"
 else
  CLANG_VER="ZyC-Clang-14.0.6"
  CLANG_URL="https://github.com/yurika-sudo/clang-repo/releases/download/clang-1/${CLANG_VER}.tar.gz"
fi

CLANG_DIR="${WORK_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VER}"
mkdir -p "$CLANG_DIR"
aria2c -x16 -s16 -d /tmp -o clang.tar.zst "$CLANG_URL"
zstd -d /tmp/clang.tar.zst --stdout | tar -xf - -C "$CLANG_DIR"
rm -f /tmp/clang.tar.zst

echo "CLANG_DIR=$CLANG_DIR" >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Toolchain ready: $CLANG_DIR"
