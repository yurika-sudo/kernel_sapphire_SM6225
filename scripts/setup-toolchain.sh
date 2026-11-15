#!/usr/bin/env bash
# setup-toolchain.sh — Neutron Clang for GKI
# env: WORK_DIR, KERNEL_SRC, SOURCE_TYPE
set -e

: "${WORK_DIR:=$GITHUB_WORKSPACE}"
: "${KERNEL_SRC:?}"
: "${SOURCE_TYPE:?}"

if [ "$SOURCE_TYPE" = "oss" ]; then
  CLANG_VER="r450784e"
  CLANG_DIR="${WORK_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VER}"
  mkdir -p "$CLANG_DIR"
  if [ ! -f "$CLANG_DIR/bin/clang" ]; then
    echo "[OSS] Downloading official AOSP clang-r450784e (matching stock kernel ABI)..."
    CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master-kernel-build-2022/clang-r450784e.tar.gz"
    curl -sSL "$CLANG_URL" | tar -xzf - -C "$CLANG_DIR"
  fi
  # Ensure dwarves (pahole >= 1.25) is available for BTF when building OSS
  if ! which pahole &>/dev/null; then
    echo "[OSS] Installing dwarves for pahole (BTF requirement)..."
    (sudo apt-get update -qq && sudo apt-get install -y -qq dwarves) || true
  fi
elif [[ "$SOURCE_TYPE" == gki* ]]; then
  CLANG_VER="06092026"
  CLANG_URL="https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/${CLANG_VER}/neutron-clang-${CLANG_VER}.tar.zst"
  CLANG_DIR="${WORK_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VER}"
  mkdir -p "$CLANG_DIR"
  aria2c -x16 -s16 -d /tmp -o clang.tar.zst "$CLANG_URL"
  zstd -d /tmp/clang.tar.zst --stdout | tar -xf - -C "$CLANG_DIR"
  rm -f /tmp/clang.tar.zst
else
  echo "[ERROR] Unsupported SOURCE_TYPE: $SOURCE_TYPE" >&2
  exit 1
fi

echo "CLANG_DIR=$CLANG_DIR" >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Toolchain ready: $CLANG_DIR"
