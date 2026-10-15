#!/usr/bin/env bash
# droidspaces.sh — DroidSpaces kernel integration
#   1. apply the SYSVIPC kABI padding patch (strict: without it, enabling the
#      IPC options shifts struct task_layout and the stock vendor modules refuse
#      to load → bootloop)
#   2. append the config set DroidSpaces probes for
#
# usage: bash scripts/droidspaces.sh <path/to/defconfig>
# env:   DROIDSPACES_TAG_PIN  use this release tag instead of the pinned one
#                            (the update workflow uses it to test a candidate)
#        PINS_FILE            optional override for sources/source-pins.json
#
# The patch URL is pinned to a release tag on purpose: the previous version of
# this script read it from `main`, so any upstream reshuffle of
# Documentation/resources/kernel-patches/ would silently switch the patch we
# build with (or silently drop it). "Check Source Updates" bumps the tag.
set -e

DEFCONFIG="${1:?usage: droidspaces.sh <path/to/defconfig>}"
[ -f "$DEFCONFIG" ] || { echo "[ERROR] defconfig not found: $DEFCONFIG" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/apply_patch.sh"

PINS_FILE="${PINS_FILE:-$SCRIPT_DIR/../sources/source-pins.json}"
_pin() {
  local KEY="$1" DEFAULT="$2" VAL=""
  if [ -f "$PINS_FILE" ] && command -v jq >/dev/null 2>&1; then
    VAL=$(jq -r ".${KEY} // empty" "$PINS_FILE" 2>/dev/null || true)
  fi
  case "$VAL" in ""|null) echo "$DEFAULT";; *) echo "$VAL";; esac
}

DS_REPO=$( _pin droidspaces_repo "ravindu644/Droidspaces-OSS")
DS_TAG="${DROIDSPACES_TAG_PIN:-$(_pin droidspaces_tag "v7.0.0")}"
DS_PATCH="001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch"
DS_PATCH_URL="https://raw.githubusercontent.com/${DS_REPO}/refs/tags/${DS_TAG}/Documentation/resources/kernel-patches/GKI/below-kernel-6.12/${DS_PATCH}"

echo "[DroidSpaces] $DS_REPO @ $DS_TAG"

# 5.4–6.6 GKI kernels take the padding patch; 5.10-and-older also needs the
# mqueue one, which we don't need on 5.15. STRICT=1 → a download failure or a
# rejected hunk aborts the build instead of producing an ABI-broken Image.
apply_patch "$DS_PATCH_URL" "droidspaces_sysvipc_kabi" "1"

# Fail if the padding didn't land: CONFIG_SYSVIPC=y below is unsafe without it.
if ! grep -q "ANDROID_KABI_USE.*sysvsem" include/linux/sched.h; then
  echo "[ERROR] $DS_PATCH is not in include/linux/sched.h — refusing to enable SYSVIPC" >&2
  echo "        Without the kABI padding, CONFIG_SYSVIPC changes exported symbol" >&2
  echo "        CRCs and the device bootloops on the stock vendor modules." >&2
  exit 1
fi
echo "[OK]  sysvipc kABI padding verified"

# ---------------------------------------------------------------------------
# Configs. Mirrors the GKI list in Documentation/Kernel-Configuration.md of the
# pinned release: required block first, then the optional-but-recommended ones.
# Everything here is kABI-safe *with* the patch above.
#
# Each line replaces any earlier assignment of the same symbol, because the base
# gki_defconfig already carries several of them (e.g. "# CONFIG_USER_NS is not
# set") and a duplicated symbol only resolves by accident of ordering.
# ---------------------------------------------------------------------------
CFG=(
  # --- required ---
  "CONFIG_SYSVIPC=y"
  "CONFIG_POSIX_MQUEUE=y"
  "CONFIG_IPC_NS=y"
  "CONFIG_PID_NS=y"
  "CONFIG_DEVTMPFS=y"
  "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y"
  # --- optional, recommended ---
  "CONFIG_USER_NS=y"                            # container sandboxing + docker "unsafe procfs"
  "CONFIG_IP6_NF_NAT=y"                         # NAT66
  "CONFIG_IP6_NF_TARGET_MASQUERADE=y"
  "CONFIG_MACVLAN=y"                            # --net=macvlan (new in DroidSpaces v7)
  "CONFIG_NETFILTER_XT_TARGET_REJECT=y"         # UFW in containers
  "CONFIG_NETFILTER_XT_TARGET_LOG=y"
  "CONFIG_NETFILTER_XT_MATCH_RECENT=y"
  "CONFIG_NETFILTER_XT_SET=y"                   # fail2ban in containers
  "CONFIG_IP_SET=y"
  "CONFIG_IP_SET_MAX=65534"
  "CONFIG_TMPFS_POSIX_ACL=y"                    # NixOS / volatile overlay
  "CONFIG_TMPFS_XATTR=y"
  "CONFIG_OVERLAY_FS=y"
  "CONFIG_OVERLAY_FS_REDIRECT_DIR=y"
  "CONFIG_OVERLAY_FS_REDIRECT_ALWAYS_FOLLOW=y"
  "CONFIG_OVERLAY_FS_INDEX=y"
  "CONFIG_OVERLAY_FS_XINO_AUTO=y"
  "CONFIG_OVERLAY_FS_METACOPY=y"
)
for TYPE in BITMAP_IP BITMAP_IPMAC BITMAP_PORT HASH_IP HASH_IPMARK HASH_IPPORT \
            HASH_IPPORTIP HASH_IPPORTNET HASH_IPMAC HASH_MAC HASH_NETPORTNET \
            HASH_NET HASH_NETNET HASH_NETPORT HASH_NETIFACE LIST_SET; do
  CFG+=("CONFIG_IP_SET_${TYPE}=y")
done

{
  echo ""
  echo "# --- DroidSpaces (see Documentation/Kernel-Configuration.md upstream) ---"
} >> "$DEFCONFIG"

for LINE in "${CFG[@]}"; do
  NAME="${LINE%%=*}"; NAME="${NAME#CONFIG_}"
  sed -i "/^CONFIG_${NAME}[= ]/d; /^# CONFIG_${NAME} /d" "$DEFCONFIG"
  echo "$LINE" >> "$DEFCONFIG"
done

# Resource limits that need no kABI-forced symbols live in setup-configs.sh
# (CONFIG_CGROUP_PIDS is enabled there — --pids-limit needs it, and this kernel
# ships its own modules plus the symbol-version force-load bypass, so the CRC
# change is handled. --cpus would additionally need CONFIG_CFS_BANDWIDTH, which
# resizes scheduler structs; deliberately left off.)

# ---------------------------------------------------------------------------
# What the DroidSpaces "Check Requirements" screen probes beyond the above.
# These are GKI defaults — one line in the log if the base ever stops providing
# them, rather than forcing options upstream says not to touch.
# ---------------------------------------------------------------------------
MISSING=()
for SYM in NAMESPACES UTS_NS SECCOMP SECCOMP_FILTER CGROUPS CGROUP_DEVICE \
           BLK_DEV_LOOP EXT4_FS FUSE_FS TUN NET_NS VETH BRIDGE NETFILTER; do
  grep -q "^CONFIG_${SYM}=y$\|^CONFIG_${SYM}=m$" "$DEFCONFIG" || MISSING+=("$SYM")
done
if [ ${#MISSING[@]} -gt 0 ]; then
  echo "[INFO] inherited from the Kconfig/GKI default, not set here: ${MISSING[*]}"
fi

echo "droidspaces: done"
