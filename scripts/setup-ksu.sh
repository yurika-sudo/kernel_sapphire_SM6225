#!/usr/bin/env bash
# setup-ksu.sh — integrate KSU variant + SUSFS into kernel source
# env: KSU_TYPE (ksun|suki|none), KERNEL_DIR, WORK_DIR
set -e

: "${KSU_TYPE:?}"
: "${KERNEL_DIR:?}"
: "${WORK_DIR:?}"

git config --global init.defaultBranch main
git config --global advice.addEmbeddedRepo false

cd "$KERNEL_DIR"

_link_ksu_driver() {
  local DIR="$1"   # KernelSU-Next or KernelSU (suki)
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

# ─── KernelSU-Next ─────────────────────────────────────────────────────────
if [ "$KSU_TYPE" = "ksun" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu ./KernelSU-Next
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" \
    | bash -s dev-susfs
  [ -d "KernelSU-Next" ] || { echo "[ERROR] KernelSU-Next not found"; exit 1; }

  cd KernelSU-Next
  git fetch --tags 2>/dev/null || true
  KSUN_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
  echo "KSUN_TAG=$KSUN_TAG"    >> "${GITHUB_ENV:-/dev/null}"
  echo "$KSUN_TAG"                  > "$WORK_DIR/ksun_tag.txt"
  cd ..

  # SUSFS — simonpunk main branch (compatible with KSU-Next)
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android13-5.15
  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "SUSFS_COMMIT=$SUSFS_COMMIT" >> "${GITHUB_ENV:-/dev/null}"
  echo "[OK] SUSFS commit: $SUSFS_COMMIT"

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --forward --fuzz=3 < "$SUSFS_PATCH" || true
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/

  _inject_susfs_init "KernelSU-Next/kernel/ksu.c"
  _link_ksu_driver "KernelSU-Next"
  rm -rf susfs4ksu

# ─── SukiSU-Ultra ──────────────────────────────────────────────────────────
elif [ "$KSU_TYPE" = "suki" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu
  curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" \
    | bash -s builtin
  [ -d "KernelSU" ] || { echo "[ERROR] KernelSU dir not found"; exit 1; }

  cd KernelSU
  # always latest — PT_REGS_PARM fixed, adb_root refactored to static_key (verified)
  git fetch --tags 2>/dev/null || true
  SUKI_TAG=$(git describe --tags --abbrev=0 2>/dev/null || \
    curl -sf "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null || echo "unknown")
  echo "SUKI_TAG=$SUKI_TAG"      >> "${GITHUB_ENV:-/dev/null}"
  echo "$SUKI_TAG"                > "$WORK_DIR/suki_ksu_tag.txt"

  # NOTE: USER_ARG_NULL fix removed — upstream builtin branch already defines
  # USER_ARG_NULL as user_arg_null_ptr() which returns struct user_arg_ptr *
  # directly. Applying &(USER_ARG_NULL) on a function-call rvalue is invalid.
  cd ..

  # SUSFS — always latest (ShirkNeko fork = simonpunk mirror, API compatible)
  git clone --depth=1 https://github.com/ShirkNeko/susfs4ksu.git -b gki-android13-5.15
  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "SUSFS_COMMIT=$SUSFS_COMMIT" >> "${GITHUB_ENV:-/dev/null}"
  echo "[OK] SUSFS commit: $SUSFS_COMMIT"

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --forward --fuzz=3 < "$SUSFS_PATCH" || true
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/

  _inject_susfs_init "KernelSU/kernel/ksu.c"
  _link_ksu_driver "KernelSU"
  rm -rf susfs4ksu

fi

echo "[OK] KSU setup complete: $KSU_TYPE"
