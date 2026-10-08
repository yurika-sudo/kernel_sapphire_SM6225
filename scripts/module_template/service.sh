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
# PowerSuspend + Big core hotplug — brightness-triggered via inotifywait
# close_write fires once per write cycle (after each dimming step)
# State guard prevents redundant writes on multi-step brightness transitions
BRIGHTNESS_NODE="/sys/class/backlight/panel0-backlight/brightness"
POWERSUSPEND_STATE="/sys/kernel/power_suspend/power_suspend_state"
POWERSUSPEND_MODE="/sys/kernel/power_suspend/power_suspend_mode"
BIG_CORES="4 5 6 7"
INOTIFY="${MODDIR}/tools/inotifywait"

_screen_off() {
  echo 1 > "$POWERSUSPEND_STATE" 2>/dev/null
  for c in $BIG_CORES; do
    echo 0 > /sys/devices/system/cpu/cpu${c}/online 2>/dev/null
  done
}

_screen_on() {
  for c in $BIG_CORES; do
    echo 1 > /sys/devices/system/cpu/cpu${c}/online 2>/dev/null
  done
  echo 0 > "$POWERSUSPEND_STATE" 2>/dev/null
}

if [ -f "$BRIGHTNESS_NODE" ] && [ -f "$POWERSUSPEND_STATE" ]; then
  echo 1 > "$POWERSUSPEND_MODE"

  # Set initial state on boot
  _PREV=""
  _VAL=$(cat "$BRIGHTNESS_NODE" 2>/dev/null)
  if [ "$_VAL" = "0" ]; then
    _screen_off; _PREV="off"
  else
    _screen_on; _PREV="on"
  fi

  "$INOTIFY" -m -e close_write "$BRIGHTNESS_NODE" 2>/dev/null | \
  while read -r _ _ _; do
    _VAL=$(cat "$BRIGHTNESS_NODE" 2>/dev/null)
    [ "$_VAL" = "0" ] && _CUR="off" || _CUR="on"
    [ "$_CUR" = "$_PREV" ] && continue
    _PREV="$_CUR"
    [ "$_CUR" = "off" ] && _screen_off || _screen_on
  done &
fi
