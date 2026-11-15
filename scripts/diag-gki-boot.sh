#!/system/bin/sh
# diag-gki-boot.sh — capture everything needed to diagnose a GKI build that
# boots but reports a wrong battery level (or any module-loading failure).
#
# Run as root on the *failing* boot:
#     su -c 'sh /data/local/tmp/diag-gki-boot.sh'
# and, for comparison, once on a *working* boot:
#     su -c 'sh /data/local/tmp/diag-gki-boot.sh'
#
# Writes /sdcard/seiran-diag-<tag>-<yyyymmdd-hhmmss>/ and a .tar.gz next to it.
# Nothing is modified on the device.

TAG="${1:-boot}"
STAMP=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo nostamp)
OUT="/sdcard/seiran-diag-$TAG-$STAMP"

mkdir -p "$OUT" || exit 1

cap() {  # cap <filename> <command...>
    f="$OUT/$1"; shift
    { "$@" 2>&1 || echo "[exit $?]"; } > "$f" 2>&1
}

# --- identity -------------------------------------------------------------
{
    echo "## uname";        uname -a
    echo "## version";      cat /proc/version
    echo "## cmdline";      cat /proc/cmdline
    echo "## uptime";       uptime
    echo "## props";        getprop ro.build.version.release
                            getprop ro.build.version.sdk
                            getprop ro.build.fingerprint
                            getprop ro.product.device
                            getprop ro.boot.bootreason
                            getprop persist.sys.boot.reason
    echo "## slot";         getprop ro.boot.slot_suffix
    echo "## seq";          cat /proc/sys/kernel/random/boot_id
} > "$OUT/00-identity.txt" 2>&1

# --- kernel config (CONFIG_IKCONFIG_PROC=y on every GKI build) ------------
if [ -r /proc/config.gz ]; then
    cat /proc/config.gz > "$OUT/config.gz"
fi
[ -r /proc/config.gz ] || echo "no /proc/config.gz" > "$OUT/config.gz.missing"

# --- kernel log -----------------------------------------------------------
dmesg > "$OUT/dmesg.txt" 2>&1
for p in 'disagrees about version' 'Unknown symbol' 'version magic' \
         'no symbol version' 'failed to load' 'module verification' \
         'deferred probe' 'probe.*failed'; do
    grep -iE "$p" "$OUT/dmesg.txt" >> "$OUT/dmesg-greps.txt" 2>&1
done
grep -iE 'smb5|qpnp|qg |bms|batt|pm7250b|spmi|vadc|iio|charger|power_supply' \
     "$OUT/dmesg.txt" > "$OUT/dmesg-power.txt" 2>&1

# --- loaded modules -------------------------------------------------------
lsmod > "$OUT/lsmod.txt" 2>&1
cat /proc/modules > "$OUT/proc-modules.txt" 2>&1

# --- power supply tree ----------------------------------------------------
{
    for d in /sys/class/power_supply/*; do
        [ -e "$d" ] || continue
        echo "=== $d -> $(readlink -f "$d")"
        for f in capacity status health present online voltage_now current_now \
                 charge_counter temp technology charge_type \
                 constant_charge_current_max input_current_limit \
                 real_capacity cycle_count; do
            [ -r "$d/$f" ] && printf '  %-24s %s\n' "$f" "$(cat "$d/$f" 2>&1)"
        done
    done
} > "$OUT/power_supply.txt" 2>&1

# --- which stock modules the ROM expects vs what actually loaded ----------
for base in /vendor/lib/modules /vendor_dlkm/lib/modules \
            /vendor_boot/lib/modules /lib/modules; do
    for lst in modules.load modules.dep modules.alias; do
        [ -r "$base/$lst" ] && cp "$base/$lst" "$OUT/$(echo "$base" | tr / _)-$lst"
    done
done
{
    echo "## loaded (name only)"
    awk '{print $1}' /proc/modules | sed 's/_$//' | sort > /tmp/.loaded
    cat /tmp/.loaded
    echo
    echo "## in modules.load but NOT loaded"
    for lst in "$OUT"/*modules.load; do
        [ -f "$lst" ] || continue
        echo "-- $lst"
        sed 's/\.ko$//' "$lst" | sort > /tmp/.want
        comm -23 /tmp/.want /tmp/.loaded
    done
} > "$OUT/module-diff.txt" 2>&1
rm -f /tmp/.loaded /tmp/.want

# --- pstore / last kmsg (usually empty on this device) --------------------
[ -d /sys/fs/pstore ] && ls -la /sys/fs/pstore > "$OUT/pstore-ls.txt" 2>&1
[ -r /proc/last_kmsg ] && cp /proc/last_kmsg "$OUT/last_kmsg.txt" 2>/dev/null

# --- pack -----------------------------------------------------------------
cd "$(dirname "$OUT")" && tar czf "$OUT.tar.gz" "$(basename "$OUT")" 2>/dev/null
echo "done: $OUT.tar.gz"
