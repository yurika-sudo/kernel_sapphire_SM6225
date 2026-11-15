#!/system/bin/sh
# wifi-restore.sh — put the internal Qualcomm radio back into STA (managed) mode.
#
# qcacld's `con_mode` module param is sticky: once it is set to 4 (monitor) the
# driver tears down the STA adapters, Android's Wi-Fi service loses wlan0 and
# usually cannot recover on its own -> reboot. This does the recovery by hand.
#
#   su -c sh /data/adb/modules/seiran-*/tools/wifi-restore.sh
P=/sys/module/wlan/parameters/con_mode

[ -e "$P" ] || { echo "con_mode not present — not a qcacld device"; exit 1; }

echo "con_mode before: $(cat "$P")"
svc wifi disable
ip link set wlan0 down 2>/dev/null
echo 0 > "$P"
ip link set wlan0 up 2>/dev/null
svc wifi enable
sleep 2

echo "con_mode after : $(cat "$P")"
ip -o link show wlan0 2>/dev/null || echo "wlan0 missing — toggle Wi-Fi once in Settings"
