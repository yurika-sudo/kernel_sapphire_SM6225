#!/usr/bin/env bash
# check-sources.sh — fetch latest upstream versions, no build
# Outputs via GITHUB_ENV for notify.sh check mode
set -e

echo "=== Checking upstream sources ==="

# ── Wild-KSU latest tag ──────────────────────────────────────────────────────
WILD_TAG=$(curl -sf "https://api.github.com/repos/WildKernels/Wild_KSU/tags" \
  | jq -r '.[0].name' 2>/dev/null || echo "unknown")
echo "Wild-KSU    : $WILD_TAG"

# ── SukiSU-Ultra latest tag ──────────────────────────────────────────────────
SUKI_TAG=$(curl -sf "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
  | jq -r '.tag_name' 2>/dev/null || echo "unknown")
echo "SukiSU-Ultra: $SUKI_TAG"

# ── SUSFS latest commit (simonpunk, gki-android13-5.15) ──────────────────────
SUSFS_RAW=$(curl -sf \
  "https://api.github.com/repos/simonpunk/susfs4ksu/commits?sha=gki-android13-5.15&per_page=1" \
  2>/dev/null || echo "[]")
SUSFS_COMMIT=$(echo "$SUSFS_RAW" | jq -r '.[0].sha[:8]' 2>/dev/null || echo "unknown")
SUSFS_DATE=$(echo "$SUSFS_RAW"   | jq -r '.[0].commit.committer.date[:10]' 2>/dev/null || echo "?")
echo "SUSFS       : $SUSFS_COMMIT ($SUSFS_DATE)"

# ── GKI 5.15 latest subversion tag ───────────────────────────────────────────
GKI_SUB=$(curl -sf \
  "https://api.github.com/repos/torvalds/linux/tags?per_page=100" \
  2>/dev/null | jq -r '[.[] | select(.name | test("^v5\\.15\\.[0-9]+$"))] | .[0].name' \
  2>/dev/null || echo "unknown")
# Fallback: AOSP kernel tags
if [ "$GKI_SUB" = "unknown" ] || [ -z "$GKI_SUB" ]; then
  GKI_SUB=$(curl -sf \
    "https://api.github.com/repos/aosp-mirror/kernel_common/tags?per_page=20" \
    2>/dev/null | jq -r '[.[] | select(.name | test("5\\.15"))] | .[0].name' \
    2>/dev/null || echo "unknown")
fi
echo "GKI 5.15    : $GKI_SUB"

# ── Write to GITHUB_ENV ──────────────────────────────────────────────────────
{
  echo "CHECK_WILD_TAG=$WILD_TAG"
  echo "CHECK_SUKI_TAG=$SUKI_TAG"
  echo "CHECK_SUSFS_COMMIT=$SUSFS_COMMIT"
  echo "CHECK_SUSFS_DATE=$SUSFS_DATE"
  echo "CHECK_GKI_SUB=$GKI_SUB"
} >> "${GITHUB_ENV:-/dev/null}"

echo "=== Done ==="
