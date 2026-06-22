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
  local DIR="$1"   # KernelSU-Next or SukiSU-Ultra
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

# KernelSU-Next
_patch_susfs_def_h() {
  # Latest susfs_def.h calls current_uid() without <linux/cred.h>.
  # Breaks compile mid-file — everything declared after call site is unseen.
  local DEF_H="include/linux/susfs_def.h"
  [ -f "$DEF_H" ] || return 0
  grep -q "linux/cred.h" "$DEF_H" && return 0
  sed -i '1i #include <linux/cred.h>' "$DEF_H"
  echo "[OK] susfs_def.h: added linux/cred.h"
}


_patch_namespace_gki_hunk1() {
  # susfs patch hunk#1 fails on GKI: trace/hooks/blk.h shifts context lines.
  # Manually applies the rejected include + extern decls + CL_COPY_MNT_NS define.
  grep -q "susfs_def.h" fs/namespace.c && return 0
  python3 - <<'EOF'
txt = open("fs/namespace.c").read()
txt = txt.replace(
    "#include <linux/mnt_idmapping.h>",
    "#include <linux/mnt_idmapping.h>\n\n"
    "#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n"
    "#include <linux/susfs_def.h>\n"
    "#endif",
    1
)
txt = txt.replace(
    '#include "internal.h"',
    '#include "internal.h"\n\n'
    "#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n"
    "extern bool susfs_is_current_ksu_domain(void);\n"
    "extern struct static_key_true susfs_is_sdcard_android_data_not_decrypted;\n\n"
    "#define CL_COPY_MNT_NS BIT(25)\n\n"
    "#endif",
    1
)
open("fs/namespace.c", "w").write(txt)
print("[OK] namespace.c: hunk#1 applied manually")
EOF
}

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
  _ksun_ver=$(grep -rh "^#define KSU_VERSION\b" KernelSU-Next/kernel/ 2>/dev/null \
  | awk 'NR==1{print $NF}' | tr -d '[:space:]')
  echo "${_ksun_ver:-}" > "$WORK_DIR/ksun_version.txt"
  cd ..

  # SUSFS — simonpunk main branch (compatible with KSU-Next)
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android13-5.15
  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "SUSFS_COMMIT=$SUSFS_COMMIT" >> "${GITHUB_ENV:-/dev/null}"
  echo "[OK] SUSFS commit: $SUSFS_COMMIT"

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --forward --fuzz=3 < "$SUSFS_PATCH" || true
  _patch_namespace_gki_hunk1
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/
  _patch_susfs_def_h

  _inject_susfs_init "KernelSU-Next/kernel/ksu.c"
  _link_ksu_driver "KernelSU-Next"
  rm -rf susfs4ksu

# SukiSU-Ultra
elif [ "$KSU_TYPE" = "suki" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu
  curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" \
    | bash -s builtin
  [ -d "KernelSU" ] || { echo "[ERROR] KernelSU dir not found"; exit 1; }

  cd KernelSU
  git fetch --tags 2>/dev/null || true
  SUKI_TAG=$(git describe --tags --abbrev=0 2>/dev/null || \
    curl -sf "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null || echo "unknown")
  echo "SUKI_TAG=$SUKI_TAG"      >> "${GITHUB_ENV:-/dev/null}"
  echo "$SUKI_TAG"                > "$WORK_DIR/suki_ksu_tag.txt"
  _suki_ver=$(grep -rh "^#define KSU_VERSION\b" KernelSU/kernel/ 2>/dev/null \
  | awk 'NR==1{print $NF}' | tr -d '[:space:]')
  echo "${_suki_ver:-}" > "$WORK_DIR/suki_version.txt"
  cd ..

  # SUSFS — (ShirkNeko fork from simonpunk main branch)
  git clone --depth=1 https://github.com/ShirkNeko/susfs4ksu.git -b gki-android13-5.15
  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "SUSFS_COMMIT=$SUSFS_COMMIT" >> "${GITHUB_ENV:-/dev/null}"
  echo "[OK] SUSFS commit: $SUSFS_COMMIT"

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --forward --fuzz=3 < "$SUSFS_PATCH" || true
  _patch_namespace_gki_hunk1
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/
  _patch_susfs_def_h

  _inject_susfs_init "KernelSU/kernel/ksu.c"
  _link_ksu_driver "KernelSU"
  rm -rf susfs4ksu

fi

echo "[OK] KSU setup complete: $KSU_TYPE"
