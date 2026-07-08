#!/usr/bin/env bash
# setup-toolchain.sh — AOSP-pinned clang for gki/gki-compat, ZyC for clo
# env: WORK_DIR, KERNEL_SRC, SOURCE_TYPE
set -e

: "${WORK_DIR:=$GITHUB_WORKSPACE}"
: "${KERNEL_SRC:?}"
: "${SOURCE_TYPE:?}"

if [[ "$SOURCE_TYPE" == gki* ]]; then
  CLANG_VER=$(grep '^CLANG_VERSION=' "$KERNEL_SRC/build.config.constants" | cut -d= -f2)
  CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/master-kernel-build-2022/clang-${CLANG_VER}.tar.gz"
else
  CLANG_VER="ZyC-Clang-23.0.0git"
  CLANG_URL="https://github.com/yurika-sudo/clang-repo/releases/download/clang-1/${CLANG_VER}.tar.gz"
fi

CLANG_DIR="${WORK_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VER}"
mkdir -p "$CLANG_DIR"
aria2c -x16 -s16 -d /tmp -o clang.tar.gz "$CLANG_URL"
tar -xzf /tmp/clang.tar.gz -C "$CLANG_DIR"
rm -f /tmp/clang.tar.gz

echo "CLANG_DIR=$CLANG_DIR" >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Toolchain ready: $CLANG_DIR"
EOF
