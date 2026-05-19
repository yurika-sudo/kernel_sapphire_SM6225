#!/usr/bin/env bash
# build-summary.sh — write GitHub Actions job summary
# env: VARIANT, KSU_TYPE, SOURCE_TYPE, BUILD_TYPE, RUN_URL
# Also used to populate GITHUB_STEP_SUMMARY

: "${VARIANT:?}"
: "${KSU_TYPE:?}"
: "${SOURCE_TYPE:?}"
: "${BUILD_TYPE:-stable}"
: "${RUN_URL:-}"

case "$KSU_TYPE" in
  wild) KSU_LABEL="Wild-KSU";  BBG="✅"; KPM="❌"; SUSFS_NOTE="simonpunk/susfs4ksu @ d8358055" ;;
  suki) KSU_LABEL="SukiSU-Ultra"; BBG="❌"; KPM="✅ KPM binary + CONFIG_KPM"; SUSFS_NOTE="ShirkNeko/susfs4ksu @ d835805" ;;
  none) KSU_LABEL="None (vanilla)"; BBG="❌"; KPM="❌"; SUSFS_NOTE="—" ;;
esac

[ "$BUILD_TYPE" = "testing" ] && BUILD_BADGE="⚠️ TESTING" || BUILD_BADGE="✅ STABLE"

KV="${KERNEL_VERSION:-unknown}"
WILD_V="${WILD_KSU_TAG:-—}"
SUKI_V="${SUKI_TAG:-—}"

# ── Console output ───────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Build Summary — ${VARIANT}  ${BUILD_BADGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Kernel   : $KV"
echo "  Source   : $SOURCE_TYPE"
echo "  KSU      : $KSU_LABEL"
[ "$KSU_TYPE" = "wild" ] && echo "  Wild ver : $WILD_V"
[ "$KSU_TYPE" = "suki" ] && echo "  Suki ver : $SUKI_V"
echo "  SUSFS    : $SUSFS_NOTE"
echo "  BBG      : $BBG"
echo "  KPM      : $KPM"
echo "  Run      : $RUN_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── GitHub step summary (Markdown) ───────────────────────────────────────────
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
cat >> "$SUMMARY" << EOF

## 🔨 ${VARIANT} — ${BUILD_BADGE}

| Field     | Value |
|-----------|-------|
| Kernel    | \`$KV\` |
| Source    | $SOURCE_TYPE |
| KSU       | $KSU_LABEL |
| Wild ver  | $WILD_V |
| Suki ver  | $SUKI_V |
| SUSFS     | $SUSFS_NOTE |
| BBG       | $BBG |
| KPM       | $KPM |

🔗 [Full run logs]($RUN_URL)
EOF
