MODDIR=${0%/*}
ZRAM_DEV=/dev/block/zram0
ZRAM_SYS=/sys/block/zram0

ORIG_MOD_DESCRIPTION=$(grep -m1 -E '^description=' ${MODDIR}/module.prop.orig | cut -d'=' -f2)
grep -vE '^description=' ${MODDIR}/module.prop.orig > ${MODDIR}/module.prop

set_status() {
	echo "description=[$1] $ORIG_MOD_DESCRIPTION" >> ${MODDIR}/module.prop
}

# If zram0 isn't even active as swap, there's nothing for us to safely swap out.
if ! grep -q "^${ZRAM_DEV}" /proc/swaps 2>/dev/null; then
	set_status "😥 zram0 not active as swap, skipping"
	exit 0
fi

# Preserve the disksize the stock module/init set up, so we restore the same size.
ORIG_DISKSIZE=$(cat ${ZRAM_SYS}/disksize 2>/dev/null)
if [ -z "$ORIG_DISKSIZE" ] || [ "$ORIG_DISKSIZE" = "0" ]; then
	set_status "😥 could not read current disksize, skipping"
	exit 0
fi

swapoff ${ZRAM_DEV} 2>/dev/null
echo 1 > ${ZRAM_SYS}/reset 2>/dev/null
# zram depends on zsmalloc, so unload in dependent-first order.
rmmod zram 2>/dev/null
rmmod zsmalloc 2>/dev/null

# Load dependency first, then the dependent module.
insmod ${MODDIR}/module/zsmalloc.ko 2>/dev/null
insmod ${MODDIR}/module/zram.ko 2>/dev/null

# Fail-safe, not fail-dangerous: if our modules didn't load, zram0 simply won't
# exist and the device runs without swap until the next reboot (which restores
# the stock modules through normal init) — it does NOT attempt a risky live
# fallback to reload the stock .ko by guessing its path.
if [ ! -e ${ZRAM_SYS}/disksize ]; then
	set_status "😥 zram.ko/zsmalloc.ko failed to load — NO SWAP until reboot"
	exit 0
fi

echo ${ORIG_DISKSIZE} > ${ZRAM_SYS}/disksize 2>/dev/null
mkswap ${ZRAM_DEV} >/dev/null 2>&1
if swapon -p -2 ${ZRAM_DEV} 2>/dev/null; then
	set_status "😋 zram.ko (multi-comp+IR) loaded, swap restored"
else
	set_status "😥 modules loaded but swapon failed — reboot recommended"
fi
sync

