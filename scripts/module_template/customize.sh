$BOOTMODE || abort "! Install this module from Magisk/KernelSU Manager, not recovery."

cat /proc/version | grep -qE '^Linux version 5\.15\.' || abort "! This module only supports the sapphire 5.15 kernel."

VARIANT_TAG="@VARIANT@"
description="Loads a zram.ko + zsmalloc.ko built with multi-comp + zram-ir recompression for kernel_sapphire_SM6225 (${VARIANT_TAG} variant). Install ONLY on a matching ${VARIANT_TAG} build — insmod will simply fail (safely) if the variant doesn't match."
echo "description=${description}" >> ${MODPATH}/module.prop
unset description
cp ${MODPATH}/module.prop ${MODPATH}/module.prop.orig

