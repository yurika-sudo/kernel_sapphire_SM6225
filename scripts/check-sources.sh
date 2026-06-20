#!/usr/bin/env bash
# check-sources.sh — fetch latest upstream versions and compare against source-pins.json
set -e

PINS_FILE="sources/source-pins.json"

# Safe curl wrapper — never fails the script
_curl() { curl -s --retry 3 --retry-delay 2 "$@" || echo ""; }

# Read a value from source-pins.json
_pin() { jq -r ".${1} // \"unknown\"" "$PINS_FILE" 2>/dev/null || echo "unknown"; }

echo "=== Fetching upstream sources ==="

# ── KSU-Next latest tag ───────────────────────────────────────────────────────
KSUN_TAG=$(_curl "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" \
  | jq -r '.[0].name // "unknown"' 2>/dev/null || echo "unknown")
[ -z "$KSUN_TAG" ] && KSUN_TAG="unknown"
echo "KSU-Next     : $KSUN_TAG"

# ── SukiSU-Ultra latest tag ───────────────────────────────────────────────────
SUKI_TAG=$(_curl "https://api.github.com/repos/SukiSU-Ultra/SukiSU-Ultra/releases/latest" \
  | jq -r '.tag_name // "unknown"' 2>/dev/null || echo "unknown")
[ -z "$SUKI_TAG" ] && SUKI_TAG="unknown"
echo "SukiSU-Ultra : $SUKI_TAG"

# ── SUSFS module latest tag ───────────────────────────────────────────────────
SUSFS_TAG=$(_curl "https://api.github.com/repos/sidex15/susfs4ksu-module/tags" \
  | jq -r 'if type=="array" and length>0 then .[0].name else "unknown" end' 2>/dev/null \
  || echo "unknown")
[ -z "$SUSFS_TAG" ] && SUSFS_TAG="unknown"
echo "SUSFS module : $SUSFS_TAG"

# ── GKI android13-5.15-lts — sublevel from Makefile ──────────────────────────
GKI_RAW=$(_curl \
  "https://android.googlesource.com/kernel/common/+/refs/heads/android13-5.15-lts/Makefile?format=TEXT")
GKI_MK=$(echo "$GKI_RAW" | base64 -d 2>/dev/null || true)
GKI_SUB=$(echo "$GKI_MK" | awk -F' *= *' \
  '/^VERSION /    {v=$2}
   /^PATCHLEVEL / {p=$2}
   /^SUBLEVEL /   {s=$2}
   END { if(v && p && s) print "v"v"."p"."s; else print "unknown" }')
GKI_SUB="${GKI_SUB:-unknown}"
echo "GKI 5.15     : $GKI_SUB"

# ── CLO kernel.lnx.5.15.r1-rel — sublevel from Makefile ──────────────────────
CLO_RAW=$(_curl \
  "https://git.codelinaro.org/clo/la/kernel/msm-5.15/-/raw/kernel.lnx.5.15.r1-rel/Makefile")
CLO_SUB=$(echo "$CLO_RAW" | awk -F' *= *' \
  '/^VERSION /    {v=$2}
   /^PATCHLEVEL / {p=$2}
   /^SUBLEVEL /   {s=$2}
   END { if(v && p && s) print "v"v"."p"."s; else print "unknown" }')
CLO_SUB="${CLO_SUB:-unknown}"
echo "CLO 5.15     : $CLO_SUB"

echo ""
echo "=== Comparing against source-pins.json ==="

PIN_GKI=$(_pin "gki_sublevel")
PIN_CLO=$(_pin "clo_sublevel")
PIN_KSUN=$(_pin "ksun_tag")
PIN_SUKI=$(_pin "suki_tag")
PIN_SUSFS=$(_pin "susfs_tag")

UPDATES=()
[ "$GKI_SUB"  != "$PIN_GKI"   ] && UPDATES+=("GKI: ${PIN_GKI} → ${GKI_SUB}")
[ "$CLO_SUB"  != "$PIN_CLO"   ] && UPDATES+=("CLO: ${PIN_CLO} → ${CLO_SUB}")
[ "$KSUN_TAG" != "$PIN_KSUN"  ] && UPDATES+=("KSU-Next: ${PIN_KSUN} → ${KSUN_TAG}")
[ "$SUKI_TAG" != "$PIN_SUKI"  ] && UPDATES+=("SukiSU: ${PIN_SUKI} → ${SUKI_TAG}")
[ "$SUSFS_TAG" != "$PIN_SUSFS" ] && UPDATES+=("SUSFS: ${PIN_SUSFS} → ${SUSFS_TAG}")

if [ ${#UPDATES[@]} -gt 0 ]; then
  echo "Updates detected:"
  for U in "${UPDATES[@]}"; do echo "  • $U"; done
  HAS_UPDATE="true"
  UPDATE_DETAIL=$(printf '%s\n' "${UPDATES[@]}")
else
  echo "All sources up to date."
  HAS_UPDATE="false"
  UPDATE_DETAIL=""
fi

# ── Write to GITHUB_ENV ───────────────────────────────────────────────────────
{
  echo "CHECK_KSUN_TAG=$KSUN_TAG"
  echo "CHECK_SUKI_TAG=$SUKI_TAG"
  echo "CHECK_SUSFS_TAG=$SUSFS_TAG"
  echo "CHECK_GKI_SUB=$GKI_SUB"
  echo "CHECK_CLO_SUB=$CLO_SUB"
  echo "HAS_UPDATE=$HAS_UPDATE"
  # Multi-line value for GITHUB_ENV
  echo "UPDATE_DETAIL<<EOF"
  echo "$UPDATE_DETAIL"
  echo "EOF"
} >> "${GITHUB_ENV:-/dev/null}"

echo "=== Done ==="
