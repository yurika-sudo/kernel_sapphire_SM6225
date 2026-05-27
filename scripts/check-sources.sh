#!/usr/bin/env bash
# check-sources.sh — fetch latest upstream versions, no build
set -e

# Safe curl wrapper — never fails the script, -s only (no -f)
_curl() { curl -s --retry 3 --retry-delay 2 "$@" || echo ""; }

echo "=== Checking upstream sources ==="

# ── Wild-KSU latest tag ──────────────────────────────────────────────────────
WILD_TAG=$(_curl "https://api.github.com/repos/WildKernels/Wild_KSU/tags" \
  | jq -r '.[0].name // "unknown"' 2>/dev/null || echo "unknown")
[ -z "$WILD_TAG" ] && WILD_TAG="unknown"
echo "Wild-KSU    : $WILD_TAG"

# ── SukiSU-Ultra latest tag ──────────────────────────────────────────────────
SUKI_TAG=$(_curl "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
  | jq -r '.tag_name // "unknown"' 2>/dev/null || echo "unknown")
[ -z "$SUKI_TAG" ] && SUKI_TAG="unknown"
echo "SukiSU-Ultra: $SUKI_TAG"

# ── SUSFS module latest tag (sidex15/susfs4ksu-module) ───────────────────────
# NOTE: This tracks the flashable SUSFS *module* version (sidex15), not the
# kernel patch commit (simonpunk). Kernel patch is pinned separately in build.
SUSFS_RAW=$(_curl \
  "https://api.github.com/repos/sidex15/susfs4ksu-module/tags" \
  || echo "[]")
SUSFS_TAG=$(echo "$SUSFS_RAW" \
  | jq -r 'if type=="array" and length>0 then .[0].name else "unknown" end' 2>/dev/null \
  || echo "unknown")
[ -z "$SUSFS_TAG" ] && SUSFS_TAG="unknown"
echo "SUSFS module: $SUSFS_TAG"

# ── GKI 5.15 latest subversion ───────────────────────────────────────────────
GKI_SUB=$(_curl "https://www.kernel.org/releases.json" \
  | jq -r '[.releases[] | select((.version | test("^5\\.15\\.")) and .moniker == "longterm")] | .[0].version // "unknown"' \
  2>/dev/null || echo "unknown")
[ -z "$GKI_SUB" ] || [ "$GKI_SUB" = "null" ] && GKI_SUB="unknown"
[[ "$GKI_SUB" != v* ]] && [[ "$GKI_SUB" != "unknown" ]] && GKI_SUB="v${GKI_SUB}"
echo "GKI 5.15    : $GKI_SUB"

# ── Write to GITHUB_ENV ──────────────────────────────────────────────────────
{
  echo "CHECK_WILD_TAG=$WILD_TAG"
  echo "CHECK_SUKI_TAG=$SUKI_TAG"
  echo "CHECK_SUSFS_TAG=$SUSFS_TAG"
  echo "CHECK_GKI_SUB=$GKI_SUB"
} >> "${GITHUB_ENV:-/dev/null}"

echo "=== Done ==="
