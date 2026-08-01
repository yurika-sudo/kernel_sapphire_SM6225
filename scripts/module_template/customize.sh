$BOOTMODE || abort "! Install this module from Magisk/KernelSU Manager, not recovery."

cat /proc/version | grep -qE '^Linux version 5\.15\.' || abort "! This module only supports the sapphire 5.15 kernel."

VARIANT_TAG="@VARIANT@"
description="zram.ko+zsmalloc.ko (multi-comp+zram-ir) · ${VARIANT_TAG} · @COMMIT@"
unset description
cp ${MODPATH}/module.prop ${MODPATH}/module.prop.orig

