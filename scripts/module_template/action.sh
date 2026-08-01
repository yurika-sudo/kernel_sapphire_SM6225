#!/system/bin/sh
if [ -f /sys/block/zram0/recomp_algorithm ]; then
	echo "- multi-comp active"
	echo "- recomp_algorithm: $(cat /sys/block/zram0/recomp_algorithm)"
	echo "- comp_algorithm:   $(cat /sys/block/zram0/comp_algorithm)"
else
	echo "- zram.ko multi-comp not active."
	echo "- Reboot may be required, or check the module description in Manager."
fi
sleep 1s

