#!/usr/bin/env bash
# resolve-versions.sh — read version info from artifacts + GitHub API
# env: BUILD_TYPE, GITHUB_ENV (implicit)
set -e

: "${BUILD_TYPE:-stable}"

VERSION_FILE=$(find ./artifacts -name "kernel_version.txt" | head -1)
KERNEL_VERSION=$([ -f "$VERSION_FILE" ] && cat "$VERSION_FILE" || echo "5.15.x")

UNAME_FILE=$(find ./artifacts -name "kernel_uname.txt" | head -1)
KERNEL_UNAME=$([ -f "$UNAME_FILE" ] && cat "$UNAME_FILE" || echo "$KERNEL_VERSION")

SUSFS_VERSION=$(curl -sf https://api.github.com/repos/sidex15/susfs4ksu-module/tags \
  | jq -r '.[0].name' | tr -d ' ' || echo "v1.5.2+_R27")

WILD_TAG=$(find ./artifacts -name "wild_ksu_tag.txt" | head -1 | xargs cat 2>/dev/null || echo "unknown")
SUKI_TAG=$(find ./artifacts -name "suki_ksu_tag.txt" | head -1 | xargs cat 2>/dev/null || echo "unknown")

DATE_TAG=$(date +'%Y%m%d')

if [ "$BUILD_TYPE" = "testing" ]; then
  RELEASE_TAG="${SUSFS_VERSION}-testing"
  RELEASE_NAME="Seiran Kernel ${SUSFS_VERSION} — Testing"
  IS_PRERELEASE="true"
else
  RELEASE_TAG="${SUSFS_VERSION}"
  RELEASE_NAME="Seiran Kernel ${SUSFS_VERSION}"
  IS_PRERELEASE="false"
fi

ENCODED_TAG=$(echo "$RELEASE_TAG" | sed 's/+/%2B/g')
RELEASE_URL="https://github.com/${GITHUB_REPOSITORY}/releases/tag/${ENCODED_TAG}"

{
  echo "KERNEL_VERSION=$KERNEL_VERSION"
  echo "KERNEL_UNAME=$KERNEL_UNAME"
  echo "SUSFS_VERSION=$SUSFS_VERSION"
  echo "WILD_TAG=$WILD_TAG"
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
echo "  Wild    : $WILD_TAG"
echo "  SukiSU  : $SUKI_TAG"
echo "  Tag     : $RELEASE_TAG"
