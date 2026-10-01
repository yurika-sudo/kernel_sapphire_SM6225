#!/system/bin/sh
# service.sh — runs after boot_completed, overrides ROM init.rc governor reset
# Wait for boot_completed then sleep to outlast ROM's late-init governor reset
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done
sleep 3
# Atheros AR9271 — load driver chain (firmware at /vendor/firmware/htc_9271.fw)
MODDIR=${0%/*}
if [ -f "${MODDIR}/module/ath9k_htc.ko" ]; then
  insmod ${MODDIR}/module/mac80211.ko 2>/dev/null
  insmod ${MODDIR}/module/ath.ko 2>/dev/null
  insmod ${MODDIR}/module/ath9k_hw.ko 2>/dev/null
  insmod ${MODDIR}/module/ath9k_common.ko 2>/dev/null
  insmod ${MODDIR}/module/ath9k_htc.ko 2>/dev/null
fi
# Reflex cpufreq governor — SM6225 has 2 fixed clusters (little: policy0, big: policy4)
echo reflex > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null
echo reflex > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor 2>/dev/null
