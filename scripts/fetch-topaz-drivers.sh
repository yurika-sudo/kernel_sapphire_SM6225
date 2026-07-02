#!/usr/bin/env bash
# fetch-topaz-drivers.sh — pull topaz-specific driver source into $KERNEL_SRC
set -e

: "${KERNEL_SRC:?}"
XIAOMI_REPO="https://github.com/MiCode/Xiaomi_Kernel_OpenSource"
XIAOMI_BRANCH="topaz-t-oss"
TMP="$(mktemp -d)"

# NOTE: only what olddefconfig needs symbols for. add more if it drops more.
PATHS=(
  drivers/input/fingerprint/Makefile
  drivers/input/fingerprint/fpc
  drivers/input/fingerprint/goodix
  drivers/power/supply/nopmi
  drivers/power/supply/battery_secret
  drivers/usb/typec/tcpc
  drivers/misc/simtray
  drivers/misc/ant_check.c
  drivers/misc/ant_check_div.c
  arch/arm64/configs/vendor/topaz_GKI.config
)

git clone --depth=1 --filter=blob:none --sparse --branch "$XIAOMI_BRANCH" \
  "$XIAOMI_REPO" "$TMP/xiaomi"
cd "$TMP/xiaomi"
git sparse-checkout init --no-cone
git sparse-checkout set "${PATHS[@]}"

for p in "${PATHS[@]}"; do
  if [ -e "$p" ]; then
    dest="$KERNEL_SRC/$p"
    # NOTE: rm -rf before copy so re-running this script never nests
    # a folder inside itself (bit us during manual runs)
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -r "$p" "$dest"
    echo "[OK] copied $p"
  else
    echo "[WARN] $p not found in topaz tree, skipping"
  fi
done

rm -rf "$TMP"
echo "[OK] topaz driver sources fetched into $KERNEL_SRC"

