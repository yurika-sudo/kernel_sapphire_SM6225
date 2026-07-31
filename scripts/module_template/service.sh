#!/system/bin/sh

MODDIR=${0%/*}
ZRAM_DEV=/dev/block/zram0
ZRAM_SYS=/sys/block/zram0

# Wait for Android to fully boot to prevent Kernel Panics
until [ "$(getprop sys.boot_completed)" = "1" ]; do
	sleep 2
done

# Extra delay to let system background processes settle
sleep 20 

# Drop caches to ensure enough physical RAM is free for swapoff
sync
echo 3 > /proc/sys/vm/drop_caches
sleep 2

ORIG_MOD_DESCRIPTION=$(grep -m1 -E '^description=' ${MODDIR}/module.prop.orig | cut -d'=' -f2)
grep -vE '^description=' ${MODDIR}/module.prop.orig > ${MODDIR}/module.prop

set_status() {
	echo "description=[$1] $ORIG_MOD_DESCRIPTION" >> ${MODDIR}/module.prop
}

IS_SWAP_ACTIVE=0
ORIG_DISKSIZE=""
if grep -q "^${ZRAM_DEV}" /proc/swaps 2>/dev/null; then
	IS_SWAP_ACTIVE=1
	ORIG_DISKSIZE=$(cat ${ZRAM_SYS}/disksize 2>/dev/null)
fi

if [ "$IS_SWAP_ACTIVE" = "1" ]; then
	swapoff ${ZRAM_DEV} 2>/dev/null
fi
[ -e ${ZRAM_SYS}/reset ] && echo 1 > ${ZRAM_SYS}/reset 2>/dev/null

# zram depends on zsmalloc, so unload in dependent-first order
rmmod zram 2>/dev/null
rmmod zsmalloc 2>/dev/null

# Load dependency first, then the dependent module.
insmod ${MODDIR}/module/zsmalloc.ko 2>/dev/null
insmod ${MODDIR}/module/zram.ko 2>/dev/null

# Fail-safe abort
if [ ! -e ${ZRAM_SYS}/disksize ]; then
	set_status "Error: zram.ko/zsmalloc.ko failed to load"
	exit 0
fi

# Set secondary algorithm (Changed to zstd as it is standard for your IR setup)
echo "algo=zstd" > ${ZRAM_SYS}/recomp_algorithm 2>/dev/null

if [ "$IS_SWAP_ACTIVE" = "1" ]; then
	echo ${ORIG_DISKSIZE} > ${ZRAM_SYS}/disksize 2>/dev/null
	mkswap ${ZRAM_DEV} >/dev/null 2>&1
    # Removed the '-p -2' parameter that caused the manual error earlier
	if swapon ${ZRAM_DEV} 2>/dev/null; then
		set_status "Active: zram.ko (multi-comp+IR) loaded, swap restored"
	else
		set_status "Error: modules loaded but swapon failed"
	fi
else
	set_status "Active: zram.ko (multi-comp+IR) loaded ahead of native swapon"
fi
sync
