#!/usr/bin/env bash
# check-sources.sh — fetch latest upstream versions, no build
set -e

# Safe curl wrapper — never fails the script, -s only (no -f)
_curl() { curl -s --retry 3 --retry-delay 2 "$@" || echo ""; }

echo "=== Checking upstream sources ==="

# ── KSU-Next latest tag ──────────────────────────────────────────────────────
KSUN_TAG=$(_curl "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" \
  | jq -r '.[0].name // "unknown"' 2>/dev/null || echo "unknown")
[ -z "$KSUN_TAG" ] && KSUN_TAG="unknown"
echo "KSU-Next    : $KSUN_TAG"

# ── SukiSU-Ultra latest tag ──────────────────────────────────────────────────
SUKI_TAG=$(_curl "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
  | jq -r '.tag_name // "unknown"' 2>/dev/null || echo "unknown")
[ -z "$SUKI_TAG" ] && SUKI_TAG="unknown"
echo "SukiSU-Ultra: $SUKI_TAG"

# ── SUSFS module latest tag (sidex15/susfs4ksu-module) ───────────────────────
# NOTE: tracks flashable SUSFS *module* version, not kernel patch commit (simonpunk)
SUSFS_RAW=$(_curl \
  "https://api.github.com/repos/sidex15/susfs4ksu-module/tags" \
  || echo "[]")
SUSFS_TAG=$(echo "$SUSFS_RAW" \
  | jq -r 'if type=="array" and length>0 then .[0].name else "unknown" end' 2>/dev/null \
  || echo "unknown")
[ -z "$SUSFS_TAG" ] && SUSFS_TAG="unknown"
echo "SUSFS module: $SUSFS_TAG"

# ── GKI android13-5.15-lts Makefile version ──────────────────────────────────
# Fetches only the Makefile (not the whole tree) via gitiles base64 endpoint.
# This reflects the actual GKI branch version, not upstream kernel.org LTS.
GKI_RAW=$(_curl \
  "https://android.googlesource.com/kernel/common/+/refs/heads/android13-5.15-lts/Makefile?format=TEXT")
GKI_MK=$(echo "$GKI_RAW" | base64 -d 2>/dev/null || true)
GKI_SUB=$(echo "$GKI_MK" | awk -F' *= *' \
  '/^VERSION /    {v=$2}
   /^PATCHLEVEL / {p=$2}
   /^SUBLEVEL /   {s=$2}
   END { if(v && p && s) print "v"v"."p"."s; else print "unknown" }')
GKI_SUB="${GKI_SUB:-unknown}"
echo "GKI 5.15    : $GKI_SUB"

# ── Write to GITHUB_ENV ──────────────────────────────────────────────────────
{
  echo "CHECK_KSUN_TAG=$KSUN_TAG"
  echo "CHECK_SUKI_TAG=$SUKI_TAG"
  echo "CHECK_SUSFS_TAG=$SUSFS_TAG"
  echo "CHECK_GKI_SUB=$GKI_SUB"
} >> "${GITHUB_ENV:-/dev/null}"

echo "=== Done ==="
