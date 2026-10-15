#!/usr/bin/env bash
# setup-toolchain.sh — fetch the Clang build pinned by the kernel source
#
# env: WORK_DIR, KERNEL_SRC
#
# The version comes from the tree's own build.config.constants (CLANG_VERSION=),
# so the toolchain always matches what this GKI revision expects.
set -e

: "${WORK_DIR:=$GITHUB_WORKSPACE}"
: "${KERNEL_SRC:?}"

CLANG_VER=$(grep '^CLANG_VERSION=' "$KERNEL_SRC/build.config.constants" | cut -d= -f2)
[ -n "$CLANG_VER" ] || { echo "[ERROR] CLANG_VERSION not found in $KERNEL_SRC/build.config.constants" >&2; exit 1; }

CLANG_URL="https://github.com/yurika-sudo/clang-repo/releases/download/clang-1/clang-${CLANG_VER}.tar.gz"
CLANG_DIR="${WORK_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VER}"

mkdir -p "$CLANG_DIR"
aria2c -x16 -s16 -d /tmp -o clang.tar.gz "$CLANG_URL"
tar -xzf /tmp/clang.tar.gz -C "$CLANG_DIR"
rm -f /tmp/clang.tar.gz

[ -x "$CLANG_DIR/bin/clang" ] || { echo "[ERROR] clang missing in $CLANG_DIR" >&2; exit 1; }

echo "CLANG_DIR=$CLANG_DIR" >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Toolchain ready: $CLANG_DIR"
