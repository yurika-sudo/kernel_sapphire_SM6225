#!/usr/bin/env bash
# setup-toolchain.sh
set -e

: "${WORK_DIR:=$GITHUB_WORKSPACE}"

CLANG_VER="ZyC-Clang-23.0.0git"
CLANG_URL="https://github.com/yurika-sudo/clang-repo/releases/download/clang-1/${CLANG_VER}.tar.gz"
CLANG_DIR="${WORK_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VER}"

mkdir -p "$CLANG_DIR"
aria2c -x16 -s16 -d /tmp -o clang.tar.gz "$CLANG_URL"
tar -xzf /tmp/clang.tar.gz -C "$CLANG_DIR"
rm -f /tmp/clang.tar.gz

echo "CLANG_DIR=$CLANG_DIR" >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Toolchain ready: $CLANG_DIR"
