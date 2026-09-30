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

echo "- cpuidle governor: $(cat /sys/devices/system/cpu/cpuidle/current_governor 2>/dev/null || echo unknown)"
echo "- I/O scheduler: $(cat $(find /sys/block/sd*/queue/scheduler 2>/dev/null | head -1) 2>/dev/null | grep -oE '\[[^]]+\]' | tr -d '[]' || echo unknown)"
echo "- cpufreq governor (policy0): $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo unknown)"
echo "- cpufreq governor (policy4): $(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_governor 2>/dev/null || echo unknown)"

echo ""
echo "- ath9k dongle (0cf3:9271): $(lsusb 2>/dev/null | grep -q '0cf3:9271' && echo 'connected' || echo 'not connected')"
echo "- cfg80211: $(lsmod | grep -q '^cfg80211' && echo "loaded ($(lsmod | grep '^cfg80211' | awk '{print $3}') users)" || echo 'not loaded')"
echo "- mac80211: $(lsmod | grep -q '^mac80211' && echo 'loaded' || echo 'not loaded')"
echo "- ath9k_htc: $(lsmod | grep -q '^ath9k_htc' && echo 'loaded' || echo 'not loaded')"
echo "- wlan: $(lsmod | grep -q '^wlan' && echo 'loaded' || echo 'rmmod (dongle active)')"
