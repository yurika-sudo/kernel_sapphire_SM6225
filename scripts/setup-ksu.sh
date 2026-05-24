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

  # SUSFS — always latest (API verified compatible with Wild canary)
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android13-5.15
  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "SUSFS_COMMIT=$SUSFS_COMMIT" >> "${GITHUB_ENV:-/dev/null}"
  echo "[OK] SUSFS commit: $SUSFS_COMMIT"

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  if [ -f "$SUSFS_PATCH" ]; then
    # Wild KSU has its own SID-based selinux integration via CONFIG_KSU_SUSFS guards.
    # Applying selinux hunks from 50_add_susfs would inject externs for symbols
    # (fake_state, ksu_selinux_hide_running, ksu_is_init_rc_hook_enabled) that
    # Wild KSU never defines, causing linker errors. Skip those hunks entirely.
    awk '/^diff --git/{skip=/security\/selinux/} !skip{print}' \
      "$SUSFS_PATCH" | patch -p1 --forward || true
  fi
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/

  # Wild KSU setuid_hook.c declares susfs_run_sus_path_loop as extern, but
  # susfs.c defines it as static — remove static to fix the linker error.
  sed -i 's/^static void susfs_run_sus_path_loop/void susfs_run_sus_path_loop/' fs/susfs.c
  echo "[OK] susfs_run_sus_path_loop exported"

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
  # always latest — PT_REGS_PARM fixed, adb_root refactored to static_key (verified)
  git fetch --tags 2>/dev/null || true
  SUKI_TAG=$(git describe --tags --abbrev=0 2>/dev/null || \
    curl -sf "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
    | jq -r '.tag_name' 2>/dev/null || echo "unknown")
  echo "SUKI_TAG=$SUKI_TAG"      >> "${GITHUB_ENV:-/dev/null}"
  echo "$SUKI_TAG"                > "$WORK_DIR/suki_ksu_tag.txt"

  # With CONFIG_KSU_SUSFS=y, the active overload of ksu_sulog_capture takes
  # struct user_arg_ptr * (pointer), but ksu_sulog_capture_grant_root passes
  # USER_ARG_NULL as a value — take its address to fix the type mismatch.
  sed -i 's/USER_ARG_NULL, gfp)/\&(USER_ARG_NULL), gfp)/' kernel/sulog/event.c
  echo "[OK] USER_ARG_NULL pointer fix applied to sulog/event.c"

  cd ..

  # SUSFS — always latest (ShirkNeko fork = simonpunk mirror, API compatible)
  git clone --depth=1 https://github.com/ShirkNeko/susfs4ksu.git -b gki-android13-5.15
  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "SUSFS_COMMIT=$SUSFS_COMMIT" >> "${GITHUB_ENV:-/dev/null}"
  echo "[OK] SUSFS commit: $SUSFS_COMMIT"

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --fuzz=3 < "$SUSFS_PATCH" || true
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/

  _inject_susfs_init "KernelSU/kernel/ksu.c"
  _link_ksu_driver "KernelSU"
  rm -rf susfs4ksu

fi

echo "[OK] KSU setup complete: $KSU_TYPE"
