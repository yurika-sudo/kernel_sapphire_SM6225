#!/usr/bin/env bash
# resolve-versions.sh — read version info from artifacts + GitHub API
# env: BUILD_TYPE, GITHUB_ENV (implicit)
set -e

: "${BUILD_TYPE:-stable}"

VERSION_FILE=$(find ./artifacts -name "kernel_version.txt" | head -1)
KERNEL_VERSION=$([ -f "$VERSION_FILE" ] && cat "$VERSION_FILE" || echo "5.15.x")

UNAME_FILE=$(find ./artifacts -name "kernel_uname.txt" | head -1)
KERNEL_UNAME=$([ -f "$UNAME_FILE" ] && cat "$UNAME_FILE" || echo "$KERNEL_VERSION")

# NOTE: pipeline exit code is from last cmd (tr), so jq failures are swallowed
# without pipefail. Use two-step fetch + explicit fallback instead.
_susfs_raw=$(curl -sf "https://api.github.com/repos/sidex15/susfs4ksu-module/tags" 2>/dev/null \
  | jq -r '.[0].name // empty' 2>/dev/null | tr -d ' \n')
SUSFS_VERSION="${_susfs_raw:-v1.5.2+_R27}"

_wf=$(find ./artifacts -name "ksun_tag.txt" | head -1)
KSUN_TAG=$([ -f "$_wf" ] && cat "$_wf" | tr -d '[:space:]' || echo "unknown")
_sf=$(find ./artifacts -name "suki_ksu_tag.txt" | head -1)
SUKI_TAG=$([ -f "$_sf" ] && cat "$_sf" | tr -d '[:space:]' || echo "unknown")
# Version codes (for manager matching)
_kv=$(find ./artifacts -name "ksun_version.txt" | head -1)
KSUN_VERSION=$([ -f "$_kv" ] && cat "$_kv" | tr -d '[:space:]' || echo "")

_sv=$(find ./artifacts -name "suki_version.txt" | head -1)
SUKI_VERSION=$([ -f "$_sv" ] && cat "$_sv" | tr -d '[:space:]' || echo "")

# Latest CI run for manager links (best-effort; falls back to Actions page)
_kr=$(curl -sf --max-time 10 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/actions/workflows/build-manager-ci.yml/runs?status=success&branch=dev&per_page=1" \
  | jq -r '.workflow_runs[0].id // empty' 2>/dev/null | tr -d '[:space:]')
KSUN_MANAGER_URL="${_kr:+https://github.com/KernelSU-Next/KernelSU-Next/actions/runs/${_kr}}"
KSUN_MANAGER_URL="${KSUN_MANAGER_URL:-https://github.com/KernelSU-Next/KernelSU-Next/actions}"

_sr=$(curl -sf --max-time 10 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/actions/workflows/build-manager.yml/runs?status=success&branch=main&per_page=1" \
  | jq -r '.workflow_runs[0].id // empty' 2>/dev/null | tr -d '[:space:]')
SUKI_MANAGER_URL="${_sr:+https://github.com/SukiSU-Ultra/SukiSU-Ultra/actions/runs/${_sr}}"
SUKI_MANAGER_URL="${SUKI_MANAGER_URL:-https://github.com/SukiSU-Ultra/SukiSU-Ultra/actions/workflows/build-manager.yml}"

DATE_TAG=$(date +'%Y%m%d')

: "${WORKFLOW_TYPE:-aio}"

if [ "$WORKFLOW_TYPE" = "compat" ]; then
  _tag_prefix="compat-"
  RELEASE_NAME="Seiran-GKI-Compat"
else
  _tag_prefix=""
  RELEASE_NAME="Seiran-GKI"
fi

if [ "$BUILD_TYPE" = "testing" ]; then
  RELEASE_TAG="${_tag_prefix}${SUSFS_VERSION}-testing"
  IS_PRERELEASE="true"
else
  RELEASE_TAG="${_tag_prefix}${SUSFS_VERSION}"
  IS_PRERELEASE="false"
fi

ENCODED_TAG=$(echo "$RELEASE_TAG" | sed 's/+/%2B/g')
RELEASE_URL="https://github.com/${GITHUB_REPOSITORY}/releases/tag/${ENCODED_TAG}"

{
  echo "KSUN_VERSION=$KSUN_VERSION"
  echo "SUKI_VERSION=$SUKI_VERSION"
  echo "KSUN_MANAGER_URL=$KSUN_MANAGER_URL"
  echo "SUKI_MANAGER_URL=$SUKI_MANAGER_URL"
  echo "KERNEL_VERSION=$KERNEL_VERSION"
  echo "KERNEL_UNAME=$KERNEL_UNAME"
  echo "SUSFS_VERSION=$SUSFS_VERSION"
  echo "KSUN_TAG=$KSUN_TAG"
  echo "SUKI_TAG=$SUKI_TAG"
  echo "DATE_TAG=$DATE_TAG"
  echo "RELEASE_TAG=$RELEASE_TAG"
  echo "RELEASE_NAME=$RELEASE_NAME"
  echo "IS_PRERELEASE=$IS_PRERELEASE"
  echo "RELEASE_URL=$RELEASE_URL"
  echo "SUSFS_MODULE_URL=https://github.com/sidex15/susfs4ksu-module/releases/latest"
} >> "${GITHUB_ENV:-/dev/null}"

echo "[OK] Versions resolved"
echo "  Kernel  : $KERNEL_VERSION"
echo "  SUSFS   : $SUSFS_VERSION"
echo "  KSU-Next: $KSUN_TAG"
echo "  SukiSU  : $SUKI_TAG"
echo "  Tag     : $RELEASE_TAG"
