#!/usr/bin/env bash
# resolve-versions.sh — read version info from artifacts + GitHub API
# env: BUILD_TYPE, GITHUB_ENV (implicit)
set -e

: "${BUILD_TYPE:-stable}"

VERSION_FILE=$(find ./artifacts -name "kernel_version.txt" | head -1)
KERNEL_VERSION=$([ -f "$VERSION_FILE" ] && cat "$VERSION_FILE" || echo "5.15.x")

UNAME_FILE=$(find ./artifacts -name "kernel_uname.txt" | head -1)
KERNEL_UNAME=$([ -f "$UNAME_FILE" ] && cat "$UNAME_FILE" || echo "$KERNEL_VERSION")

# GKI and CLO pin different upstream sublevels (see sources/source-pins.json), so an
# aio release (both sources bundled together) actually has two distinct kernel bases,
# not one. KERNEL_VERSION/KERNEL_UNAME above collapse to whichever artifact `find`
# happens to list first (alphabetically "clo-*" beats "gki-*"), which silently hid
# the GKI side. Resolve each source independently here so downstream scripts can show
# both. Artifact dirs are named "gki-<ksu>" / "clo-<ksu>" (see build-aio.yml matrix);
# GKI-Compat artifacts are "gkicompat-<ksu>", which doesn't match "gki-*", so on a
# compat build these two just come back empty and callers fall back to the single
# KERNEL_VERSION/KERNEL_UNAME above — no separate compat-specific branch needed.
GKI_VERSION_FILE=$(find ./artifacts -path "*gki-*" -name "kernel_version.txt" | head -1)
CLO_VERSION_FILE=$(find ./artifacts -path "*clo-*" -name "kernel_version.txt" | head -1)
GKI_UNAME_FILE=$(find ./artifacts -path "*gki-*" -name "kernel_uname.txt" | head -1)
CLO_UNAME_FILE=$(find ./artifacts -path "*clo-*" -name "kernel_uname.txt" | head -1)

KERNEL_VERSION_GKI=$([ -f "$GKI_VERSION_FILE" ] && cat "$GKI_VERSION_FILE" || echo "")
KERNEL_VERSION_CLO=$([ -f "$CLO_VERSION_FILE" ] && cat "$CLO_VERSION_FILE" || echo "")
KERNEL_UNAME_GKI=$([ -f "$GKI_UNAME_FILE" ] && cat "$GKI_UNAME_FILE" || echo "$KERNEL_VERSION_GKI")
KERNEL_UNAME_CLO=$([ -f "$CLO_UNAME_FILE" ] && cat "$CLO_UNAME_FILE" || echo "$KERNEL_VERSION_CLO")

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
KSUN_MANAGER_ARTIFACT_ID=$([ -n "$_kr" ] && \
  curl -sf --max-time 10 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/actions/runs/${_kr}/artifacts" \
  | jq -r '.artifacts[] | select(.name == "manager") | .id // empty' | head -1 || true)
  
KSUN_MANAGER_SPOOFED_ARTIFACT_ID=$([ -n "$_kr" ] && \
  curl -sf --max-time 10 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/actions/runs/${_kr}/artifacts" \
  | jq -r '.artifacts[] | select(.name == "manager-spoofed") | .id // empty' | head -1 || true)  

_sr=$(curl -sf --max-time 10 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/actions/workflows/build-manager.yml/runs?status=success&branch=main&per_page=1" \
  | jq -r '.workflow_runs[0].id // empty' 2>/dev/null | tr -d '[:space:]')
SUKI_MANAGER_URL="${_sr:+https://github.com/SukiSU-Ultra/SukiSU-Ultra/actions/runs/${_sr}}"
SUKI_MANAGER_URL="${SUKI_MANAGER_URL:-https://github.com/SukiSU-Ultra/SukiSU-Ultra/actions/workflows/build-manager.yml}"
SUKI_MANAGER_ARTIFACT_ID=$([ -n "$_sr" ] && \
  curl -sf --max-time 10 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/actions/runs/${_sr}/artifacts" \
  | jq -r '.artifacts[] | select(.name | ascii_downcase == "manager") | .id // empty' | head -1 || true)

SUKI_MANAGER_SPOOFED_ARTIFACT_ID=$([ -n "$_sr" ] && \
  curl -sf --max-time 10 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/actions/runs/${_sr}/artifacts" \
  | jq -r '.artifacts[] | select(.name | ascii_downcase == "spoofed-manager") | .id // empty' | head -1 || true)

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
  echo "KSUN_MANAGER_ARTIFACT_ID=$KSUN_MANAGER_ARTIFACT_ID"
  echo "KSUN_MANAGER_SPOOFED_ARTIFACT_ID=$KSUN_MANAGER_SPOOFED_ARTIFACT_ID"
  echo "SUKI_MANAGER_ARTIFACT_ID=$SUKI_MANAGER_ARTIFACT_ID"
  echo "SUKI_MANAGER_SPOOFED_ARTIFACT_ID=$SUKI_MANAGER_SPOOFED_ARTIFACT_ID"
  echo "KERNEL_VERSION=$KERNEL_VERSION"
  echo "KERNEL_UNAME=$KERNEL_UNAME"
  echo "KERNEL_VERSION_GKI=$KERNEL_VERSION_GKI"
  echo "KERNEL_VERSION_CLO=$KERNEL_VERSION_CLO"
  echo "KERNEL_UNAME_GKI=$KERNEL_UNAME_GKI"
  echo "KERNEL_UNAME_CLO=$KERNEL_UNAME_CLO"
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
if [ -n "$KERNEL_UNAME_GKI" ] && [ -n "$KERNEL_UNAME_CLO" ]; then
  echo "  GKI base: $KERNEL_UNAME_GKI"
  echo "  CLO base: $KERNEL_UNAME_CLO"
else
  echo "  Kernel  : $KERNEL_VERSION"
fi
echo "  SUSFS   : $SUSFS_VERSION"
echo "  KSU-Next: $KSUN_TAG"
echo "  SukiSU  : $SUKI_TAG"
echo "  Tag     : $RELEASE_TAG"
