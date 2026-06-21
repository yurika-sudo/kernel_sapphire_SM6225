#!/usr/bin/env bash
# build-summary.sh — write GitHub Actions job summary
# env: VARIANT, KSU_TYPE, SOURCE_TYPE, BUILD_TYPE, RUN_URL
# Also used to populate GITHUB_STEP_SUMMARY

: "${VARIANT:?}"
: "${KSU_TYPE:?}"
: "${SOURCE_TYPE:?}"
: "${BUILD_TYPE:-stable}"
: "${RUN_URL:-}"

_SUSFS_COMMIT="${SUSFS_COMMIT:-latest}"

case "$KSU_TYPE" in
  ksun) KSU_LABEL="KSU-Next";      BBG="✅"; KPM="❌";                       SUSFS_NOTE="simonpunk/susfs4ksu @ $_SUSFS_COMMIT" ;;
  suki) KSU_LABEL="SukiSU-Ultra";  BBG="❌"; KPM="✅ KPM binary + CONFIG_KPM"; SUSFS_NOTE="ShirkNeko/susfs4ksu @ $_SUSFS_COMMIT" ;;
  none) KSU_LABEL="None (vanilla)"; BBG="❌"; KPM="❌";                       SUSFS_NOTE="—" ;;
esac

[ "$BUILD_TYPE" = "testing" ] && BUILD_BADGE="⚠️ TESTING" || BUILD_BADGE="✅ STABLE"

KV="${KERNEL_VERSION:-unknown}"
KSUN_V="${KSUN_KSU_TAG:-—}"
SUKI_V="${SUKI_TAG:-—}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Build Summary — ${VARIANT}  ${BUILD_BADGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Kernel   : $KV"
echo "  Source   : $SOURCE_TYPE"
echo "  KSU      : $KSU_LABEL"
[ "$KSU_TYPE" = "ksun" ] && echo "  KSU-Next : $KSUN_V"
[ "$KSU_TYPE" = "suki" ] && echo "  Suki ver : $SUKI_V"
echo "  SUSFS    : $SUSFS_NOTE"
echo "  BBG      : $BBG"
echo "  KPM      : $KPM"
echo "  Run      : $RUN_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


