#!/usr/bin/env bash
# build-oss.sh — Qualcomm layout OSS builder for Seiran Kernel (sapphire/sapphiren)
# env: WORK_DIR, KERNEL_SRC, CLANG_DIR, KSU_TYPE, SOURCE_TYPE
set -e

: "${WORK_DIR:=$PWD}"
: "${KERNEL_SRC:=$WORK_DIR/kernel_src}"
: "${CLANG_DIR:?set CLANG_DIR to clang toolchain path (e.g. clang-r450784e)}"
: "${KSU_TYPE:=ksun}"
SOURCE_TYPE="oss"

export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-superuseryu}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github}"
export PATH="${CLANG_DIR}/bin:$PATH"

ROOT="$KERNEL_SRC"
K="$ROOT/kernel_platform/msm-kernel"
G="$ROOT/kernel_platform/gki-stock"
V="$ROOT/vendor/qcom/opensource"
OUT_DIR="${WORK_DIR}/out"
DIST_DIR="${OUT_DIR}/dist"
VENDOR_DLKM_DIR="${DIST_DIR}/vendor_dlkm"

mkdir -p "$DIST_DIR" "$VENDOR_DLKM_DIR" "$K/out"

# Modern Clang (LLVM 16+) warning & error suppressions
export KCFLAGS="-D__ANDROID_COMMON_KERNEL__ -Wno-error -Wno-uninitialized-const-pointer -Wno-unknown-warning-option -Wno-array-bounds -Wno-implicit-int -Wno-int-conversion"
export KBUILD_MODPOST_WARN=1

# Clean dirty flag and strip -dirty from setlocalversion
if [ -f "$K/scripts/setlocalversion" ]; then
	sed -i 's/-dirty//' "$K/scripts/setlocalversion"
fi
echo "+" > "$K/.scmversion" 2>/dev/null || true

# Fix sys_regs.c uninitialized const pointer on modern Clang (LLVM 18+)
SYS_REGS="$K/arch/arm64/kvm/sys_regs.c"
if [ -f "$SYS_REGS" ]; then
	sed -i 's/struct sys_reg_desc clidr;/struct sys_reg_desc clidr = { 0 };/' "$SYS_REGS"
fi

# Fix missing bool return type in msm_vidc_driver.h on modern Clang (LLVM 16+)
VIDC_HDR="$V/video-driver/driver/vidc/inc/msm_vidc_driver.h"
if [ -f "$VIDC_HDR" ]; then
	sed -i 's/static inline is_/static inline bool is_/g' "$VIDC_HDR"
fi

JOBS=${JOBS:-$(nproc)}
MK="make -j$JOBS ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu-"

echo "=============================================="
echo " [SEIRAN-OSS] Starting Qualcomm OSS Build"
echo " Target : sapphire / sapphiren (SM6225)"
echo " Root   : $ROOT"
echo " Out    : $OUT_DIR"
echo " KSU    : $KSU_TYPE"
echo " Jobs   : $JOBS"
echo "=============================================="

# 1. Config Phase
echo ">> [1/4] Preparing Defconfig & Merging Fragments..."
cp "$ROOT/build/stock_defconfig" "$K/out/.config"

(cd "$K" && KCONFIG_CONFIG=out/.config scripts/kconfig/merge_config.sh -m -O out out/.config \
	arch/arm64/configs/vendor/bengal_GKI.config arch/arm64/configs/vendor/sapphire_GKI.config >/dev/null)

# Normalize against stock GKI defconfig so KMI remains untouched
python3 - "$ROOT/build/stock_defconfig" "$K/out/.config" <<'PY'
import re, sys
def load(p):
    d = {}
    for l in open(p):
        l = l.strip()
        m = re.match(r'^(CONFIG_\w+)=(.*)$', l)
        if m: d[m.group(1)] = m.group(2); continue
        m = re.match(r'^# (CONFIG_\w+) is not set', l)
        if m: d[m.group(1)] = None
    return d
g, o = load(sys.argv[1]), load(sys.argv[2])
for k, v in g.items():
    if v not in (None, 'm') and o.get(k) != v:
        o[k] = v
with open(sys.argv[2], 'w') as f:
    for k, v in o.items():
        f.write(f'# {k} is not set\n' if v is None else f'{k}={v}\n')
PY

# Apply Seiran configs (Nuke WALT, BTF=y, Cambyses CFS, ZRAM-IR, BBR3, KSU/SUSFS)
echo ">> [1/4] Injecting Seiran Kernel custom configs..."
KSU_TYPE="$KSU_TYPE" SOURCE_TYPE="oss" DEFCONFIG="$K/out/.config" KERNEL_DIR="$K" \
	bash "${WORK_DIR}/scripts/setup-configs.sh"

# Enforce ThinLTO and strip unused whitelist
(cd "$K" && scripts/config --file out/.config \
	-d LTO_CLANG_FULL \
	-e LTO_CLANG_THIN \
	-d TRIM_UNUSED_KSYMS \
	-u UNUSED_KSYMS_WHITELIST)

$MK -C "$K" O=out olddefconfig >/dev/null

# 2. Kernel Compilation Phase
echo ">> [2/4] Building Image, vmlinux, and modules_prepare..."
$MK -C "$K" O=out Image vmlinux modules_prepare

if [ -f "$K/out/arch/arm64/boot/Image" ]; then
	cp "$K/out/arch/arm64/boot/Image" "$DIST_DIR/Image"
	echo "✅ Image ready at $DIST_DIR/Image"
else
	echo "❌ Image build failed!"
	exit 1
fi

# Copy generated vmlinux as BTF base for vendor modules
cp "$K/out/vmlinux" "$G/vmlinux"

# Synchronize symbol tables so modpost finds symbols and does not warn about missing Module.symvers
if [ -f "$K/out/vmlinux.symvers" ]; then
	cp "$K/out/vmlinux.symvers" "$K/out/Module.symvers"
	cp "$K/out/vmlinux.symvers" "$K/Module.symvers"
	cp "$K/out/vmlinux.symvers" "$G/vmlinux.symvers"
	cp "$K/out/vmlinux.symvers" "$G/Module.symvers"
fi
if [ -f "$K/out/System.map" ]; then
	cp "$K/out/System.map" "$G/System.map"
fi

# 3. Vendor Out-of-Tree Modules Phase
echo ">> [3/4] Building Vendor DLKM Modules via KBUILD_MIXED_TREE..."
MIX="KBUILD_MIXED_TREE=$G"
VMK="$MK -C $K O=out $MIX KBUILD_MODPOST_WARN=1"
sym() { for d in "$@"; do printf "%s " "$V/$d/Module.symvers"; done; }
b() { local n=$1 d=$2; shift 2; echo "  -> Building $n..."; $VMK M="$V/$d" modules "$@" >/dev/null; }

# Fix missing mmrm-driver/test directory in FirstPlace tree
if [ ! -d "$V/mmrm-driver/test" ] && [ -f "$V/mmrm-driver/Kbuild" ]; then
	sed -i '/obj-m += test\//d' "$V/mmrm-driver/Kbuild"
fi

b mmrm      mmrm-driver MMRM_ROOT="$V/mmrm-driver" BOARD_PLATFORM=bengal
b video     video-driver VIDEO_ROOT="$V/video-driver" MODNAME=msm_video BOARD_PLATFORM=bengal KBUILD_EXTRA_SYMBOLS="$(sym mmrm-driver)"
b securemsm securemsm-kernel SSG_MODULE_ROOT="$V/securemsm-kernel" BOARD_PLATFORM=bengal CONFIG_DSQB=y
b ipa       dataipa/drivers/platform/msm 'CONFIG_LOCALVERSION="-perf"' DATAIPA_ROOT="$V/dataipa" BOARD_PLATFORM=bengal
b rmnet     datarmnet/core RMNET_CORE_ROOT="$V/datarmnet/core" BOARD_PLATFORM=bengal KBUILD_EXTRA_SYMBOLS="$V/dataipa/drivers/platform/msm/Module.symvers"
b rmnetwlan datarmnet-ext/wlan KCFLAGS="$KCFLAGS -Wno-error=misleading-indentation -I$V/datarmnet/core" BOARD_PLATFORM=bengal KBUILD_EXTRA_SYMBOLS="$V/datarmnet/core/Module.symvers"
b audio     audio-kernel AUDIO_ROOT="$V/audio-kernel" MODNAME=audio_dlkm BOARD_PLATFORM=bengal KBUILD_EXTRA_SYMBOLS="$ROOT/build/stock-closed.symvers"
b wlanplat  wlan/platform WLAN_PLATFORM_ROOT="$V/wlan/platform" CONFIG_CNSS_OUT_OF_TREE=y CONFIG_ICNSS2=m CONFIG_ICNSS2_QMI=y CONFIG_CNSS_GENL=m CONFIG_WCNSS_MEM_PRE_ALLOC=m CONFIG_CNSS_UTILS=m CONFIG_CNSS_QMI_SVC=m KBUILD_EXTRA_SYMBOLS="$(sym securemsm-kernel)"
b bt        bt-kernel BT_ROOT="$V/bt-kernel" BT_KERNEL_ROOT="$V/bt-kernel" CONFIG_MSM_BT_POWER=m CONFIG_BTFM_SLIM=m CONFIG_I2C_RTC6226_QCA=m KBUILD_EXTRA_SYMBOLS="$(sym wlan/platform)"

# 4. Collection Phase
echo ">> [4/4] Collecting & Stripping Tested Modules..."
STRIP_BIN=$(command -v llvm-strip || command -v aarch64-linux-gnu-strip || command -v strip)
local_count=0
while read -r m path; do
	case "$m" in ''|\#*) continue ;; esac
	SRC_KO="$V/$path"
	if [ -f "$SRC_KO" ]; then
		"$STRIP_BIN" --strip-debug -o "$VENDOR_DLKM_DIR/$m.ko" "$SRC_KO"
		local_count=$((local_count + 1))
	else
		echo "  [WARN] Module not found: $path"
	fi
done < "$ROOT/build/TESTED_MODULES.txt"

echo "✅ Collected $local_count tested vendor modules into $VENDOR_DLKM_DIR"

# Write version file
echo "5.15.194-seiran-oss" > "$DIST_DIR/kernel_version.txt"
echo "=============================================="
echo " [SEIRAN-OSS] Build completed successfully!"
echo "=============================================="
