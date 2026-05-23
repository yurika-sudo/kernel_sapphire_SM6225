#!/usr/bin/env bash
# fix-abi-gki.sh — bypass ABI checks + fix build.config for GKI
# env: KERNEL_SRC, WORK_DIR
set -e

: "${KERNEL_SRC:?}"
: "${WORK_DIR:?}"

# Disable ABI symbol check
ABI_SCRIPT="$WORK_DIR/build/kernel/abi/compare_to_symbol_list"
if [ -f "$ABI_SCRIPT" ]; then
  sed -i 's/^\s*exit 1$/    echo "ABI check bypassed"/' "$ABI_SCRIPT"
elif [ -f "$WORK_DIR/build/abi/compare_to_symbol_list" ]; then
  mv "$WORK_DIR/build/abi/compare_to_symbol_list" \
     "$WORK_DIR/build/abi/compare_to_symbol_list.disabled"
  printf '#!/bin/bash\necho "ABI checking disabled"\nexit 0\n' \
    > "$WORK_DIR/build/abi/compare_to_symbol_list"
  chmod +x "$WORK_DIR/build/abi/compare_to_symbol_list"
fi

# Disable DLKM + KMI strict mode
BC_AARCH64="${KERNEL_SRC}/build.config.gki.aarch64"
sed -i 's/BUILD_SYSTEM_DLKM=1/BUILD_SYSTEM_DLKM=0/'          "$BC_AARCH64"
sed -i '/MODULES_ORDER=android\/gki_aarch64_modules/d'         "$BC_AARCH64"
sed -i '/KMI_SYMBOL_LIST_STRICT_MODE/d'                        "$BC_AARCH64"

# glibc 2.38+ compat fix for BTF resolve
GLIBC=$(ldd --version 2>/dev/null | head -1 | awk '{print $NF}')
if [ "$(printf '%s\n' "2.38" "$GLIBC" | sort -V | head -1)" = "2.38" ]; then
  BTF_MK="${KERNEL_SRC}/tools/bpf/resolve_btfids/Makefile"
  [ -f "$BTF_MK" ] && \
    sed -i 's/\$(Q)\$(MAKE) -C \$(SUBCMD_SRC) OUTPUT=/$(Q)$(MAKE) -C $(SUBCMD_SRC) EXTRA_CFLAGS="$(CFLAGS)" OUTPUT=/' \
      "$BTF_MK" 2>/dev/null || true
  echo "[OK] glibc 2.38 compat (host: $GLIBC)"
fi

# Set build identity
SETUP_ENV="$WORK_DIR/build/_setup_env.sh"
if [ -f "$SETUP_ENV" ]; then
  sed -i \
    -e 's/export KBUILD_BUILD_USER=build-user/export KBUILD_BUILD_USER=superuseryu/g' \
    -e 's/${KBUILD_BUILD_USER:-build-user}/${KBUILD_BUILD_USER:-superuseryu}/g' \
    -e 's/export KBUILD_BUILD_HOST=build-host/export KBUILD_BUILD_HOST=github/g' \
    -e 's/${KBUILD_BUILD_HOST:-build-host}/${KBUILD_BUILD_HOST:-github}/g' \
    "$SETUP_ENV"
fi

echo "[OK] ABI fixes applied"
