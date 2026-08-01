#!/usr/bin/env bash
# build-summary.sh — write detailed build summary to Runner + save to file for audit zip
# env: BUILD_TYPE, ZIP_MODE, REPO, SHA, RELEASE_TAG, RELEASE_URL,
#      KSUN_TAG, SUKI_TAG, SUSFS_VERSION, SUSFS_MODULE_URL,
#      KERNEL_VERSION, GITHUB_RUN_NUMBER, GITHUB_STEP_SUMMARY
set -e

: "${BUILD_TYPE:-stable}"
: "${REPO:?}"
: "${SHA:?}"

SHORT_SHA="${SHA:0:9}"
COMMIT_URL="https://github.com/${REPO}/commit/${SHA}"
DATE_NOW=$(date -u +'%Y-%m-%d %H:%M UTC')

[ "$BUILD_TYPE" = "testing" ] && BUILD_LABEL="⚠️ Testing" || BUILD_LABEL="✅ Stable"

# Collect variant ZIPs for download table
VARIANT_TABLE=""
for ZIP in ./release_zips/AnyKernel3_*.zip; do
  [ -f "$ZIP" ] || continue
  NAME=$(basename "$ZIP")
  SIZE=$(echo "scale=1; $(stat -c%s "$ZIP") / 1024 / 1024" | bc)
  DL_URL="${RELEASE_URL}#:~:text=${NAME}"
  VARIANT_TABLE="${VARIANT_TABLE}"$'\n'"| [\`${NAME}\`](${RELEASE_URL}) | ${SIZE} MB |"
done

SUMMARY=""
SUMMARY="${SUMMARY}# 🌸 Seiran Kernel — Build Summary"$'\n\n'
SUMMARY="${SUMMARY}| | |"$'\n'
SUMMARY="${SUMMARY}|---|---|"$'\n'
SUMMARY="${SUMMARY}| **Build** | Run #${GITHUB_RUN_NUMBER} · ${BUILD_LABEL} |"$'\n'
SUMMARY="${SUMMARY}| **Tag** | \`${RELEASE_TAG}\` |"$'\n'
if [ -n "${KERNEL_VERSION_GKI:-}" ] && [ -n "${KERNEL_VERSION_CLO:-}" ]; then
  SUMMARY="${SUMMARY}| **Kernel base (GKI)** | \`${KERNEL_VERSION_GKI}\` |"$'\n'
  SUMMARY="${SUMMARY}| **Kernel base (CLO)** | \`${KERNEL_VERSION_CLO}\` |"$'\n'
else
  SUMMARY="${SUMMARY}| **Kernel base** | \`${KERNEL_VERSION}\` |"$'\n'
fi
SUMMARY="${SUMMARY}| **Commit** | [\`${SHORT_SHA}\`](${COMMIT_URL}) |"$'\n'
SUMMARY="${SUMMARY}| **Date** | ${DATE_NOW} |"$'\n'
SUMMARY="${SUMMARY}| **Pack mode** | ${ZIP_MODE:-per-variant} |"$'\n\n'

SUMMARY="${SUMMARY}## 📦 KSU / SUSFS Versions"$'\n\n'
SUMMARY="${SUMMARY}| Component | Version | Link |"$'\n'
SUMMARY="${SUMMARY}|-----------|---------|------|"$'\n'
SUMMARY="${SUMMARY}| KSU-Next | \`${KSUN_TAG}\` | [Releases](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/${KSUN_TAG}) |"$'\n'
SUMMARY="${SUMMARY}| SukiSU-Ultra | \`${SUKI_TAG}\` | [Releases](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/${SUKI_TAG}) |"$'\n'
SUMMARY="${SUMMARY}| SUSFS module | \`${SUSFS_VERSION}\` | [Download](${SUSFS_MODULE_URL}) |"$'\n\n'

SUMMARY="${SUMMARY}## ✨ Features"$'\n\n'
SUMMARY="${SUMMARY}- SUSFS v2.1.0"$'\n'
SUMMARY="${SUMMARY}- BBR+Westwood TCP (Westwood default)"$'\n'
SUMMARY="${SUMMARY}- BBG (Ksun variants)"$'\n'
SUMMARY="${SUMMARY}- KPM support (SukiSU variants)"$'\n'
SUMMARY="${SUMMARY}- Thin LTO"$'\n'
SUMMARY="${SUMMARY}- Droidspaces"$'\n\n'

SUMMARY="${SUMMARY}## 🗂️ Variants & Downloads"$'\n\n'
SUMMARY="${SUMMARY}| File | Size |"$'\n'
SUMMARY="${SUMMARY}|------|------|"
SUMMARY="${SUMMARY}${VARIANT_TABLE}"$'\n\n'
SUMMARY="${SUMMARY}🔗 [Release page](${RELEASE_URL})"$'\n\n'

SUMMARY="${SUMMARY}---"$'\n'
SUMMARY="${SUMMARY}> ⏳ This Runner summary expires in **~1 day** (retention policy)."$'\n'
SUMMARY="${SUMMARY}> 📥 Full details preserved in \`build-audit-logs-*.zip\` → extract \`build_summary.md\`."

# Write to Runner summary
echo "$SUMMARY" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

# Save copy for audit zip (picked up by audit-logs.sh)
mkdir -p ./audit_logs
echo "$SUMMARY" > ./audit_logs/build_summary.md

echo "[OK] Build summary written"
