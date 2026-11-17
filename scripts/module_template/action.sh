#!/system/bin/sh
MODDIR=${0%/*}
IW="${MODDIR}/tools/iw"
MDIR="${MODDIR}/module"

# -- Dongle status --
DONGLE_CONNECTED=0
lsusb 2>/dev/null | grep -q "0cf3:9271" && DONGLE_CONNECTED=1
ATH9K_LOADED=0
lsmod | grep -q "^ath9k_htc" && ATH9K_LOADED=1

RTL8188GU_CONNECTED=0
lsusb 2>/dev/null | grep -qE "0bda:b711|0bda:2005" && RTL8188GU_CONNECTED=1
RTL8188GU_LOADED=0
lsmod | grep -q "^8188gu" && RTL8188GU_LOADED=1

if [ $DONGLE_CONNECTED -eq 1 ] || [ $ATH9K_LOADED -eq 1 ] || [ $RTL8188GU_CONNECTED -eq 1 ] || [ $RTL8188GU_LOADED -eq 1 ]; then
echo "dongle (0cf3:9271 / AR9271): $([ $DONGLE_CONNECTED -eq 1 ] && echo 'connected' || echo 'not connected')"
echo "ath9k_htc: $([ $ATH9K_LOADED -eq 1 ] && echo 'loaded' || echo 'not loaded')"
echo "dongle (0bda:b711|2005 / RTL8188GU): $([ $RTL8188GU_CONNECTED -eq 1 ] && echo 'connected' || echo 'not connected')"
echo "8188gu: $([ $RTL8188GU_LOADED -eq 1 ] && echo 'loaded' || echo 'not loaded')"
echo "cfg80211: $([ -d /sys/module/cfg80211 ] && echo 'loaded' || echo 'missing')"
echo "mac80211: $(lsmod | grep -q '^mac80211' && echo 'loaded' || echo 'not loaded')"
echo "wlan: $(lsmod | grep -q '^wlan' && echo 'loaded' || echo 'not loaded')"
echo "wlan0/wlan0mon: $(ip link show 2>/dev/null | grep -qE 'wlan0|wlan0mon' && echo 'up/present' || echo 'not present')"
echo ""
fi


# -- Smart toggle (no arg) --
if [ -z "$1" ]; then
  if [ $DONGLE_CONNECTED -eq 1 ] && [ $ATH9K_LOADED -eq 0 ]; then
    set -- activate
  elif [ $DONGLE_CONNECTED -eq 0 ] && [ $ATH9K_LOADED -eq 1 ]; then
    set -- deactivate
  elif [ $RTL8188GU_CONNECTED -eq 1 ] && [ $RTL8188GU_LOADED -eq 0 ]; then
    set -- activate-rtl
  elif [ $RTL8188GU_CONNECTED -eq 0 ] && [ $RTL8188GU_LOADED -eq 1 ]; then
    set -- deactivate-rtl
  else
    echo ">> Nothing to toggle, launching Seiran..."
    am start --user 0 -n id.seiran.app/.MainActivity >/dev/null 2>&1 || echo "!! Seiran app not installed"
    exit 0
  fi
fi

# -- Activate (AR9271 / TL-WN722N) --
if [ "$1" = "activate" ]; then
  if [ $DONGLE_CONNECTED -eq 0 ]; then
    echo "!! Dongle not detected. Plug in TL-WN722N first."
    exit 1
  fi
  if [ $ATH9K_LOADED -eq 1 ]; then
    echo "!! ath9k_htc already loaded. Deactivate first."
    exit 1
  fi
  echo ">> Activating AR9271 dongle..."
  # cfg80211 is the ROM's own module; never touch the vendor qcacld module
  # (`wlan`) — unloading it is what used to kill internal Wi-Fi until reboot.
  lsmod | grep -q "^mac80211" || insmod $MDIR/mac80211.ko || { echo "!! mac80211 failed"; exit 1; }
  lsmod | grep -q "^ath " || insmod $MDIR/ath.ko       || { echo "!! ath failed"; exit 1; }
  lsmod | grep -q "^ath9k_hw" || insmod $MDIR/ath9k_hw.ko  || { echo "!! ath9k_hw failed"; exit 1; }
  lsmod | grep -q "^ath9k_common" || insmod $MDIR/ath9k_common.ko || { echo "!! ath9k_common failed"; exit 1; }
  insmod $MDIR/ath9k_htc.ko && echo "  ath9k_htc ok" || { echo "!! ath9k_htc failed"; exit 1; }
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

# -- Activate RTL (RTL8188GU) --
if [ "$1" = "activate-rtl" ]; then
  if [ $RTL8188GU_CONNECTED -eq 0 ]; then
    echo "!! RTL8188GU not detected. Plug in dongle first."
    exit 1
  fi
  if [ $RTL8188GU_LOADED -eq 1 ]; then
    echo "!! 8188gu already loaded. Deactivate first."
    exit 1
  fi
  echo ">> Activating RTL8188GU dongle..."
  # cfg80211 is the ROM's own module; never unload the vendor qcacld module.
  lsmod | grep -q "^mac80211" || insmod $MDIR/mac80211.ko || { echo "!! mac80211 failed"; exit 1; }
  insmod $MDIR/8188gu.ko && echo "  8188gu ok" || { echo "!! 8188gu failed"; exit 1; }
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

# -- Deactivate (AR9271 / TL-WN722N) --
if [ "$1" = "deactivate" ]; then
  echo ">> Deactivating AR9271 dongle..."
  ip link set wlan0mon down 2>/dev/null
  $IW dev wlan0mon del 2>/dev/null
  rmmod ath9k_htc 2>/dev/null && echo "  ath9k_htc unloaded"
  # mac80211/cfg80211 stay loaded: cfg80211 belongs to the ROM and mac80211 is shared
  # with the other dongles. Nothing here touches `wlan`, so internal Wi-Fi keeps
  # working and no reboot is needed.
  echo ">> Done."
  exit 0
fi

# -- Deactivate RTL (RTL8188GU) --
if [ "$1" = "deactivate-rtl" ]; then
  echo ">> Deactivating RTL8188GU dongle..."
  ip link set wlan0mon down 2>/dev/null
  $IW dev wlan0mon del 2>/dev/null
  rmmod 8188gu 2>/dev/null && echo "  8188gu unloaded"
  echo ">> Done."
  exit 0
fi

echo "!! Unknown action: $1"
exit 1
