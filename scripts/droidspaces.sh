#!/usr/bin/env bash
# droidspaces.sh — apply kABI fix + append required kernel configs
# usage: source scripts/apply_patch.sh && bash scripts/droidspaces.sh <defconfig_path>
set -e
source "$(dirname "$0")/apply_patch.sh"

DEFCONFIG="${1:?usage: droidspaces.sh <path/to/defconfig>}"

apply_patch \
  "https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/refs/heads/main/Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch" \
  "droidspaces_sysvipc_kabi" \
  "1"

cat >> "$DEFCONFIG" << 'EOF'
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_IPC_NS=y
CONFIG_PID_NS=y
CONFIG_DEVTMPFS=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_TARGET_REJECT=y
CONFIG_NETFILTER_XT_TARGET_LOG=y
CONFIG_NETFILTER_XT_MATCH_RECENT=y
CONFIG_NETFILTER_XT_SET=y
CONFIG_NF_TABLES=y
CONFIG_NF_TABLES_INET=y
CONFIG_NF_TABLES_NETDEV=y
CONFIG_NF_TABLES_IPV4=y
CONFIG_NF_TABLES_IPV6=y
CONFIG_NF_TABLES_ARP=y
CONFIG_NFT_CT=y
CONFIG_NFT_COUNTER=y
CONFIG_NFT_LOG=y
CONFIG_NFT_LIMIT=y
CONFIG_NFT_MASQ=y
CONFIG_NFT_REDIR=y
CONFIG_NFT_NAT=y
CONFIG_NFT_QUOTA=y
CONFIG_NFT_REJECT=y
CONFIG_NFT_REJECT_INET=y
CONFIG_NFT_REJECT_IPV4=y
CONFIG_NFT_REJECT_IPV6=y
CONFIG_NFT_TPROXY=y
CONFIG_NFT_COMPAT=y
EOF

echo "droidspaces: done"
