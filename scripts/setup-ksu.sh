#!/usr/bin/env bash
# setup-ksu.sh — integrate KSU variant + SUSFS into kernel source
# env: KSU_TYPE (wild|suki|none), KERNEL_DIR, WORK_DIR
set -e

: "${KSU_TYPE:?}"
: "${KERNEL_DIR:?}"
: "${WORK_DIR:?}"

cd "$KERNEL_DIR"

_link_ksu_driver() {
  local DIR="$1"   # KernelSU or Wild_KSU
  [ ! -L "drivers/kernelsu" ] && [ ! -d "drivers/kernelsu" ] && \
    ln -sf "../${DIR}" drivers/kernelsu
  grep -q "obj-.*kernelsu" drivers/Makefile || \
    echo 'obj-$(CONFIG_KSU) += kernelsu/' >> drivers/Makefile
  grep -q "kernelsu/Kconfig" drivers/Kconfig || \
    echo 'source "drivers/kernelsu/Kconfig"' >> drivers/Kconfig
}

_inject_susfs_init() {
  local KSU_C="$1"
  [ ! -f "$KSU_C" ] && return 0
  grep -q "susfs_init" "$KSU_C" && return 0

  grep -q "#include <linux/susfs.h>" "$KSU_C" || \
    sed -i '/#include <linux\/fs\.h>/a #include <linux\/susfs.h>/' "$KSU_C" || true
  grep -q "susfs_init()" "$KSU_C" || \
    sed -i '/ksu_core_init();/a \\tsusfs_init();' "$KSU_C" || \
    sed -i '/int __init ksu_init(/,/^}/{ /return 0;/i \\tsusfs_init(); }' "$KSU_C" || true
  echo "[OK] susfs_init injected into $KSU_C"
}

# ─── Wild-KSU ──────────────────────────────────────────────────────────────
if [ "$KSU_TYPE" = "wild" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu ./Wild_KSU
  curl -LSs "https://raw.githubusercontent.com/WildKernels/Wild_KSU/wild/kernel/setup.sh" \
    | bash -s canary
  [ -d "Wild_KSU" ] || { echo "[ERROR] Wild_KSU not found"; exit 1; }

  cd Wild_KSU
  git fetch --tags 2>/dev/null || true
  WILD_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
  echo "WILD_KSU_TAG=$WILD_TAG"    >> "${GITHUB_ENV:-/dev/null}"
  echo "$WILD_TAG"                  > "$WORK_DIR/wild_ksu_tag.txt"
  cd ..

  # SUSFS — pinned d8358055 (pre-static_key, pairs clean w/ Wild canary)
  git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android13-5.15
  cd susfs4ksu && git checkout d8358055 && cd ..

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --forward < "$SUSFS_PATCH" || true
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*           fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/

  _inject_susfs_init "Wild_KSU/kernel/ksu.c"
  _link_ksu_driver "Wild_KSU"
  rm -rf susfs4ksu

# ─── SukiSU-Ultra ──────────────────────────────────────────────────────────
elif [ "$KSU_TYPE" = "suki" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu
  curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" \
    | bash -s builtin
  [ -d "KernelSU" ] || { echo "[ERROR] KernelSU dir not found"; exit 1; }

  cd KernelSU
  # d43e250 — pre-adb_root, no PT_REGS_PARM errors on 5.15
  git fetch --depth=100 2>/dev/null || true
  git checkout d43e250
  git fetch --tags 2>/dev/null || true
  SUKI_TAG=$(git describe --tags --abbrev=0 2>/dev/null || \
    curl -sf "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null || echo "unknown")
  echo "SUKI_TAG=$SUKI_TAG"      >> "${GITHUB_ENV:-/dev/null}"
  echo "$SUKI_TAG"                > "$WORK_DIR/suki_ksu_tag.txt"
  cd ..

  # SUSFS — d835805 (proven pair w/ d43e250 SukiSU on 5.15)
  git clone https://github.com/ShirkNeko/susfs4ksu.git -b gki-android13-5.15
  cd susfs4ksu && git checkout d835805 && cd ..

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --fuzz=3 < "$SUSFS_PATCH" || true
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*           fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/

  _inject_susfs_init "KernelSU/kernel/ksu.c"
  _link_ksu_driver "KernelSU"
  rm -rf susfs4ksu

fi

echo "[OK] KSU setup complete: $KSU_TYPE"
