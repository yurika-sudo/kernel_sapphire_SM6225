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
  "https://api.github.com/repos/simonpunk/susfs4ksu/commits?sha=gki-android13-5.15&per_page=1")
SUSFS_COMMIT=$(echo "$SUSFS_RAW" | jq -r 'if type=="array" then .[0].sha[:8] else "unknown" end' 2>/dev/null || echo "unknown")
SUSFS_DATE=$(echo "$SUSFS_RAW"   | jq -r 'if type=="array" then .[0].commit.committer.date[:10] else "?" end' 2>/dev/null || echo "?")
echo "SUSFS       : $SUSFS_COMMIT ($SUSFS_DATE)"

# ── GKI 5.15 latest subversion ───────────────────────────────────────────────
# Check android kernel common repo tags via googlesource
GKI_SUB=$(curl -sf \
  "https://api.github.com/repos/gregkh/linux/tags?per_page=100" \
  | jq -r '[.[] | select(.name | test("^v5\\.15\\.[0-9]+$"))] | .[0].name // "unknown"' \
  2>/dev/null || echo "unknown")
# Fallback: stable kernel releases list
if [ "$GKI_SUB" = "unknown" ] || [ -z "$GKI_SUB" ]; then
  GKI_SUB=$(curl -sf "https://www.kernel.org/releases.json" \
    | jq -r '.releases[] | select(.version | test("^5\\.15\\.")) | .version' \
    | sort -V | tail -1 | sed 's/^/v/' 2>/dev/null || echo "unknown")
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
