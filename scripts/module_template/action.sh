#!/system/bin/sh
MODDIR=${0%/*}
IW="${MODDIR}/tools/iw"
MDIR="${MODDIR}/module"

# -- Status (always) --
if [ -f /sys/block/zram0/recomp_algorithm ]; then
  echo "zram multi-comp: active"
  echo "recomp_algorithm: $(cat /sys/block/zram0/recomp_algorithm)"
  echo "comp_algorithm:   $(cat /sys/block/zram0/comp_algorithm)"
else
  echo "zram multi-comp: not active"
fi
echo "cpuidle: $(cat /sys/devices/system/cpu/cpuidle/current_governor 2>/dev/null || echo unknown)"
echo "I/O scheduler: $(cat $(find /sys/block/sd*/queue/scheduler 2>/dev/null | head -1) 2>/dev/null | grep -oE '\[[^]]+\]' | tr -d '[]' || echo unknown)"
echo "cpufreq policy0: $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo unknown)"
GOV4=$(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_governor 2>/dev/null || echo unknown)
if [ "$GOV4" = "vorpal" ]; then
  GM=$(cat /sys/devices/system/cpu/cpufreq/policy4/vorpal/gaming_mode 2>/dev/null)
  [ "$GM" = "1" ] && GM_LABEL="gaming" || GM_LABEL="daily"
  echo "cpufreq policy4: vorpal [$GM_LABEL]"
else
  echo "cpufreq policy4: $GOV4"
fi
echo ""

# -- Dongle status --
DONGLE_CONNECTED=0
lsusb 2>/dev/null | grep -q "0cf3:9271" && DONGLE_CONNECTED=1
ATH9K_LOADED=0
lsmod | grep -q "^ath9k_htc" && ATH9K_LOADED=1

echo "dongle (0cf3:9271): $([ $DONGLE_CONNECTED -eq 1 ] && echo 'connected' || echo 'not connected')"
echo "ath9k_htc: $([ $ATH9K_LOADED -eq 1 ] && echo 'loaded' || echo 'not loaded')"
echo "cfg80211: $(lsmod | grep -q '^cfg80211' && echo "loaded ($(lsmod | grep '^cfg80211' | awk '{print $3}') users)" || echo 'not loaded')"
echo "mac80211: $(lsmod | grep -q '^mac80211' && echo 'loaded' || echo 'not loaded')"
echo "wlan: $(lsmod | grep -q '^wlan' && echo 'loaded' || echo 'not loaded')"
echo "wlan0/wlan0mon: $(ip link show 2>/dev/null | grep -qE 'wlan0|wlan0mon' && echo 'up/present' || echo 'not present')"
echo ""

# -- Vorpal gaming_mode toggle (no arg) --
GOV4=$(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_governor 2>/dev/null)
if [ -z "$1" ] && [ "$GOV4" = "vorpal" ]; then
  GM_PATH=/sys/devices/system/cpu/cpufreq/policy4/vorpal/gaming_mode
  GM=$(cat "$GM_PATH" 2>/dev/null)
  if [ "$GM" = "1" ]; then
    echo 0 > "$GM_PATH"
    echo ">> Vorpal: switched to daily mode"
  else
    echo 1 > "$GM_PATH"
    echo ">> Vorpal: switched to gaming mode"
  fi
  exit 0
fi

# -- Smart toggle (no arg) --
if [ -z "$1" ]; then
  if [ $DONGLE_CONNECTED -eq 1 ] && [ $ATH9K_LOADED -eq 0 ]; then
    set -- activate
  elif [ $DONGLE_CONNECTED -eq 0 ] && [ $ATH9K_LOADED -eq 1 ]; then
    set -- deactivate
  else
    exit 0
  fi
fi

# -- Activate --
if [ "$1" = "activate" ]; then
  if [ $DONGLE_CONNECTED -eq 0 ]; then
    echo "!! Dongle not detected. Plug in TL-WN722N first."
    exit 1
  fi
  if [ $ATH9K_LOADED -eq 1 ]; then
    echo "!! ath9k_htc already loaded. Deactivate first."
    exit 1
  fi
  echo ">> Activating dongle..."
  echo ">> Replacing vendor cfg80211 with GKI version..."
  rmmod wlan 2>/dev/null && echo "  wlan unloaded" || echo "  wlan not loaded (ok)"
  sleep 1
  rmmod cfg80211 2>/dev/null && echo "  cfg80211 (vendor) unloaded" || echo "  cfg80211 not loaded (ok)"
  insmod $MDIR/cfg80211.ko  && echo "  cfg80211 (GKI) ok" || { echo "!! cfg80211 failed"; exit 1; }
  insmod $MDIR/mac80211.ko  && echo "  mac80211 ok"       || { echo "!! mac80211 failed"; exit 1; }
  insmod $MDIR/ath.ko       && echo "  ath ok"            || { echo "!! ath failed"; exit 1; }
  insmod $MDIR/ath9k_hw.ko  && echo "  ath9k_hw ok"      || { echo "!! ath9k_hw failed"; exit 1; }
  insmod $MDIR/ath9k_common.ko && echo "  ath9k_common ok" || { echo "!! ath9k_common failed"; exit 1; }
  insmod $MDIR/ath9k_htc.ko && echo "  ath9k_htc ok"     || { echo "!! ath9k_htc failed"; exit 1; }
  echo ">> Waiting for phy..."
  PHY=""
  for i in $(seq 1 15); do
    PHY=$(ls /sys/class/ieee80211/ 2>/dev/null | tail -1)
    [ -n "$PHY" ] && break
    sleep 1
  done
  if [ -z "$PHY" ]; then
    echo "!! No phy registered. Try unplugging and replugging the dongle."
    exit 1
  fi
  echo ">> phy: $PHY"
  IFACE=$($IW dev | grep -B1 "phy#${PHY#phy}" | grep Interface | awk '{print $2}' | head -1)
  [ -z "$IFACE" ] && IFACE="wlan0"
  ip link set $IFACE down 2>/dev/null
  $IW dev $IFACE set type monitor
  ip link set $IFACE up
  echo ">> Interface ready in monitor mode."
  exit 0
fi

# -- Deactivate --
if [ "$1" = "deactivate" ]; then
  echo ">> Deactivating dongle..."
  ip link set wlan0mon down 2>/dev/null
  $IW dev wlan0mon del 2>/dev/null
  rmmod ath9k_htc 2>/dev/null && echo "  ath9k_htc unloaded"
  sleep 1
  rmmod ath9k_common 2>/dev/null
  rmmod ath9k_hw 2>/dev/null
  rmmod ath 2>/dev/null
  rmmod mac80211 2>/dev/null && echo "  mac80211 unloaded"
  rmmod cfg80211 2>/dev/null && echo "  cfg80211 (GKI) unloaded"
  sleep 1
  insmod /vendor_dlkm/lib/modules/cfg80211.ko && echo "  cfg80211 (vendor) restored" || { echo "!! cfg80211 vendor restore failed"; exit 1; }
  echo ""
  echo "WiFi needs a reboot to come back. Rebooting in 5 seconds..."
  sleep 5
  reboot
  exit 0
fi

echo "!! Unknown action: $1"
exit 1
