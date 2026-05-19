#!/usr/bin/env bash
# release-notes.sh — generate release body
# env: BUILD_TYPE, RUN_URL, REPO, SHA, RUN_NUMBER
#      WILD_TAG, SUKI_TAG, SUSFS_VERSION, SUSFS_MODULE_URL, KERNEL_VERSION
set -e

: "${BUILD_TYPE:-stable}"
: "${RUN_URL:?}"
: "${REPO:?}"
: "${SHA:?}"

SHORT_SHA="${SHA:0:9}"
COMMIT_URL="https://github.com/${REPO}/commit/${SHA}"

BODY=""

# Testing warning banner
[ "$BUILD_TYPE" = "testing" ] && \
  BODY="> ⚠️ **Testing build** — experimental configs active, use at own risk."$'\n\n'

# Versions block
BODY="${BODY}**Wild-KSU:** [${WILD_TAG}](https://github.com/WildKernels/Wild_KSU/releases/tag/${WILD_TAG})"$'\n'
BODY="${BODY}**SukiSU-Ultra:** [${SUKI_TAG}](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/${SUKI_TAG})"$'\n'
BODY="${BODY}**SUSFS module:** [${SUSFS_VERSION}](${SUSFS_MODULE_URL})"$'\n'
BODY="${BODY}**Kernel base:** \`${KERNEL_VERSION}\`"$'\n\n'

# Variants + features
BODY="${BODY}**Variants:** GKI Wild · GKI SukiSU · GKI NoKSU · CLO Wild · CLO SukiSU · CLO NoKSU"$'\n'
BODY="${BODY}**Features:** SUSFS · BBG (Wild) · KPM (SukiSU) · Thin LTO · Droidspaces · BBR+Westwood"$'\n\n'

# Links
BODY="${BODY}**Commit:** [\`${SHORT_SHA}\`](${COMMIT_URL})"$'\n'
BODY="${BODY}**Flash via** OrangeFox / TWRP · [t.me/home_yu_chat](https://t.me/home_yu_chat)"$'\n\n'

# Run summary link (per-build detail)
BODY="${BODY}📋 **Per-build details:** [Run #${GITHUB_RUN_NUMBER} summary](${RUN_URL})"$'\n'
BODY="${BODY}> Full build logs in \`build-audit-logs-*.zip\` below."

# Write to GITHUB_ENV as multiline
{
  echo "RELEASE_BODY<<EOREL"
  echo "$BODY"
  echo "EOREL"
} >> "${GITHUB_ENV:-/dev/null}"

echo "[OK] Release body generated"
