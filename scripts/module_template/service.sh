#!/system/bin/sh
# service.sh — runs after boot_completed, overrides ROM init.rc governor reset
# Wait for boot_completed then sleep to outlast ROM's late-init governor reset
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done
sleep 3
MODDIR=${0%/*}
_SP=/data/adb/seiran
# Seiran Tune: saved pick if valid, else default
_pick() {
  _v=$(cat "$_SP/$1" 2>/dev/null)
  [ -n "$_v" ] && case " $(cat "$3" 2>/dev/null | tr -d '[]' | tr '\n' ' ') " in
    *" $_v "*) echo "$_v"; return;;
  esac
  echo "$2"
}
# USB Wi-Fi dongles — loaded once at boot so plugging one in is plug-and-play.
# Every step is logged to /data/adb/seiran-wifi.log; stderr used to be discarded,
# which hid missing modules and unresolved symbols.
_WLOG=/data/adb/seiran-wifi.log
_insmod() {
  [ -f "${MODDIR}/module/${1}.ko" ] || return 0
  grep -q "^${1} " /proc/modules && return 0
  if insmod "${MODDIR}/module/${1}.ko" 2>>"$_WLOG"; then
    echo "ok   ${1}" >>"$_WLOG"
  else
    echo "FAIL ${1}" >>"$_WLOG"
  fi
}
: > "$_WLOG"
# Firmware must be reachable at /vendor/firmware (where this module ships
# htc_9271.fw). Android normally sets this path; append it if it is missing so
# ath9k_htc's request_firmware() cannot fail with -ENOENT.
_FWP=$(cat /sys/module/firmware_class/parameters/path 2>/dev/null)
case ",$_FWP," in
  *,/vendor/firmware,*) ;;
  *) echo "${_FWP:+$_FWP,}/vendor/firmware" > \
       /sys/module/firmware_class/parameters/path 2>/dev/null ;;
esac
# AR9271 (TL-WN722N v1) — mac80211 based; cfg80211 is the ROM's own module.
_insmod mac80211
_insmod ath
_insmod ath9k_hw
_insmod ath9k_common
_insmod ath9k_htc
# State snapshot so a failing chain can be diagnosed without a reboot
{
  echo "--- state after load ---"
  grep -E '^(cfg80211|mac80211|ath|ath9k)' /proc/modules
  ls -l /vendor/firmware/htc_9271.fw
  echo "firmware path: $(cat /sys/module/firmware_class/parameters/path 2>/dev/null)"
  ${MODDIR}/tools/iw dev
  ip -o link
} >> "$_WLOG" 2>&1
# Vorpal cpufreq governor — SM6225 has 2 fixed clusters (little: policy0, big: policy4)
_GV=$(_pick cpufreq vorpal /sys/devices/system/cpu/cpufreq/policy0/scaling_available_governors)
echo "$_GV" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null
echo "$_GV" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor 2>/dev/null
# PowerSuspend + Big core hotplug — brightness-triggered via inotifywait
# close_write fires once per write cycle (after each dimming step)
# State guard prevents redundant writes on multi-step brightness transitions
BRIGHTNESS_NODE="/sys/class/backlight/panel0-backlight/brightness"
POWERSUSPEND_STATE="/sys/kernel/power_suspend/power_suspend_state"
POWERSUSPEND_MODE="/sys/kernel/power_suspend/power_suspend_mode"
INOTIFY="${MODDIR}/tools/inotifywait"

_screen_off() {
  echo 1 > "$POWERSUSPEND_STATE" 2>/dev/null
}

_screen_on() {
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
