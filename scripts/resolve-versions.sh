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
