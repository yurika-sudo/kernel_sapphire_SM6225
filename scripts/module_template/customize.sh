$BOOTMODE || abort "! Install this module from Magisk/KernelSU Manager, not recovery."

cat /proc/version | grep -qE '^Linux version 5\.15\.' || abort "! This module only supports the sapphire 5.15 kernel."

VARIANT_TAG="@VARIANT@"
description="zram.ko+zsmalloc.ko (multi-comp+zram-ir) for ${VARIANT_TAG}. Wrong variant = safe fail, no harm."
echo "description=${description}" >> ${MODPATH}/module.prop
unset description
cp ${MODPATH}/module.prop ${MODPATH}/module.prop.orig

