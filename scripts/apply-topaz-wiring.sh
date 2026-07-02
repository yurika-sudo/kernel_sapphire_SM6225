#!/usr/bin/env bash
# apply-topaz-wiring.sh — wire topaz driver dirs into Kconfig/Makefile trees.
# Safe to re-run: every insert is guarded by a grep -q check first.
# Run AFTER fetch-topaz-drivers.sh, from $KERNEL_SRC.
set -e

: "${KERNEL_SRC:?}"
cd "$KERNEL_SRC"

insert_before() {
  # insert_before <marker_regex> <file> <text>
  local marker="$1" file="$2" text="$3"
  grep -qF "$text" "$file" && return 0   # already applied
  local line
  line=$(grep -n "$marker" "$file" | head -1 | cut -d: -f1)
  [ -z "$line" ] && { echo "[ERR] marker '$marker' not found in $file"; exit 1; }
  sed -i "${line}i${text}" "$file"
  echo "[OK] inserted into $file before '$marker'"
}

append_once() {
  # append_once <file> <text>
  local file="$1" text="$2"
  grep -qF "$text" "$file" && return 0
  echo "$text" >> "$file"
  echo "[OK] appended to $file"
}

# drivers/input/fingerprint/Kconfig (create if missing)
FP_KCONFIG="drivers/input/fingerprint/Kconfig"
if [ ! -f "$FP_KCONFIG" ]; then
  cat > "$FP_KCONFIG" << 'EOF'
menu "Fingerprint sensor devices"

config INPUT_FINGERPRINT
	tristate "fingerprint drvier support"
	help
	  say y here to enable  fingerprint driver support!

source "drivers/input/fingerprint/fpc/Kconfig"
source "drivers/input/fingerprint/goodix/Kconfig"

endmenu
EOF
  echo "[OK] created $FP_KCONFIG"
fi

# drivers/input/Kconfig: source the fingerprint menu (outside any nested submenu)
insert_before "^endmenu$" drivers/input/Kconfig \
  'source "drivers/input/fingerprint/Kconfig"'
# NOTE: if drivers/input/Kconfig has multiple endmenu (nested submenus),
# verify the FIRST match is the outermost one for your tree before trusting this.

# drivers/input/Makefile: build the fingerprint dir
append_once drivers/input/Makefile 'obj-y += fingerprint/'

# drivers/power/supply/Kconfig: NOPMI_CHARGER symbol + source subdirs
insert_before "^endif # POWER_SUPPLY$" drivers/power/supply/Kconfig \
  'config NOPMI_CHARGER\n\ttristate "NOPMI Charger Support"\n\tdepends on FG_SM5602 \&\& BQ2589X_CHARGER\n\thelp\n\t  Say Y to include support for NOPMI Charger.\n\nsource "drivers/power/supply/battery_secret/Kconfig"\nsource "drivers/power/supply/nopmi/Kconfig"'

# drivers/power/supply/Makefile
append_once drivers/power/supply/Makefile 'obj-$(CONFIG_NOPMI_CHARGER)     += nopmi/'
append_once drivers/power/supply/Makefile 'obj-$(CONFIG_BATT_VERIFY_BY_DS28E16)    += battery_secret/'

# drivers/misc/Kconfig: ANT_CHECK symbols + source simtray
insert_before "^endmenu$" drivers/misc/Kconfig \
  'source "drivers/misc/simtray/Kconfig"\n\nconfig ANT_CHECK\n\ttristate "ant check gpio"\n\thelp\n\t  Say '"'"'y'"'"' here to include support for the QTI QPNP MISC\n\t  peripheral. The MISC peripheral holds the USB ID interrupt\n\t  and the driver provides an API to check if this interrupt\n\t  is available on the current PMIC chip.\n\nconfig ANT_CHECK_DIV\n\ttristate "ant check div gpio"\n\thelp\n\t  Say '"'"'y'"'"' here to include support for ant check div gpio.'

# drivers/misc/Makefile
append_once drivers/misc/Makefile 'obj-$(CONFIG_SIMTRAY_STATUS)    += simtray/'
append_once drivers/misc/Makefile 'obj-$(CONFIG_ANT_CHECK)         += ant_check.o'
append_once drivers/misc/Makefile 'obj-$(CONFIG_ANT_CHECK_DIV)     += ant_check_div.o'

# drivers/usb/typec/Kconfig: source tcpc/Kconfig OUTSIDE the `if TYPEC` block
# TCPC_CLASS does `select TYPEC`, so sourcing it inside `if TYPEC ... endif`
# creates a recursive dependency. Must live AFTER `endif # TYPEC`.
if ! grep -qF 'source "drivers/usb/typec/tcpc/Kconfig"' drivers/usb/typec/Kconfig; then
  sed -i '/^endif # TYPEC$/a\
\
source "drivers/usb/typec/tcpc/Kconfig"' drivers/usb/typec/Kconfig
  echo "[OK] sourced tcpc/Kconfig after endif # TYPEC"
fi

echo "[OK] topaz Kconfig/Makefile wiring applied"
