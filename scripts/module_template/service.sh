#!/system/bin/sh
# service.sh — runs after boot_completed, overrides vendor/PowerHAL governor reset
# Reflex cpufreq governor — SM6225 has 2 fixed clusters (little: policy0, big: policy4)
echo reflex > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null
echo reflex > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor 2>/dev/null
