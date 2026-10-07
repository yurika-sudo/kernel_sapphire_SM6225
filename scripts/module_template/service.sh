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
echo vorpal > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null
echo vorpal > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor 2>/dev/null

# PowerSuspend — brightness-triggered userspace hook via inotifywait
BRIGHTNESS_NODE="/sys/class/backlight/panel0-backlight/brightness"
POWERSUSPEND_STATE="/sys/kernel/power_suspend/power_suspend_state"
POWERSUSPEND_MODE="/sys/kernel/power_suspend/power_suspend_mode"

if [ -f "$BRIGHTNESS_NODE" ] && [ -f "$POWERSUSPEND_STATE" ]; then
  # Set userspace mode so sysfs writes are accepted
  echo 1 > "$POWERSUSPEND_MODE"
  # Monitor brightness node for any write event, react immediately
  "${MODDIR}/tools/inotifywait" -m -e close_write "$BRIGHTNESS_NODE" 2>/dev/null | \
  while read -r _ _ _; do
    BRIGHTNESS=$(cat "$BRIGHTNESS_NODE")
    if [ "$BRIGHTNESS" = "0" ]; then
      echo 1 > "$POWERSUSPEND_STATE"
    else
      echo 0 > "$POWERSUSPEND_STATE"
    fi
  done &
fi
