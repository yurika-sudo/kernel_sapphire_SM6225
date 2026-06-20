#!/usr/bin/env bash
# release-notes.sh — generate release body
# env: BUILD_TYPE, RUN_URL, REPO, SHA, RUN_NUMBER
#      KSUN_TAG, SUKI_TAG, SUSFS_VERSION, SUSFS_MODULE_URL, KERNEL_VERSION
set -e

: "${BUILD_TYPE:-stable}"
: "${WORKFLOW_TYPE:-aio}"
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
BODY="${BODY}**KSU-Next:** [${KSUN_TAG}](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/${KSUN_TAG})"$'\n'
BODY="${BODY}**SukiSU-Ultra:** [${SUKI_TAG}](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/${SUKI_TAG})"$'\n'
BODY="${BODY}**SUSFS module:** [${SUSFS_VERSION}](${SUSFS_MODULE_URL})"$'\n'
BODY="${BODY}**Kernel base:** \`${KERNEL_VERSION}\`"$'\n\n'

# Variants + supported — differ by workflow type
if [ "$WORKFLOW_TYPE" = "compat" ]; then
  BODY="${BODY}**Variants:** GKI-Compat KSU-Next · GKI-Compat SukiSU · GKI-Compat NoKSU"$'\n\n'
  BODY="${BODY}**Supported:** Android 13 / 14"$'\n'
else
  BODY="${BODY}**Variants:** GKI Ksun · GKI SukiSU · GKI NoKSU · CLO Ksun · CLO SukiSU · CLO NoKSU"$'\n\n'
  BODY="${BODY}**Supported:** Android 15+"$'\n'
fi

BODY="${BODY}**Issues / bug reports:** [t.me/home_yu_chat](https://t.me/home_yu_chat)"$'\n'
BODY="${BODY}**Critical issues:** PM directly"$'\n\n'

# Known issues (compat: manager needs latest CI build)
if [ "$WORKFLOW_TYPE" = "compat" ]; then
  BODY="${BODY}> ⚠️ **Known issue:** KSU / SukiSU manager may show \"Failed to update App Profile\" on older stable builds. Update to the latest CI manager — [get it here](https://t.me/tmplogchat/310)"$'\n\n'
fi

# Commit + run detail
BODY="${BODY}**Commit:** [\`${SHORT_SHA}\`](${COMMIT_URL})"$'\n'
BODY="${BODY}📋 **Per-build details:** [Run #${GITHUB_RUN_NUMBER} summary](${RUN_URL})"$'\n'
BODY="${BODY}> Full build logs in \`build-audit-logs-*.zip\` below."

# Write to GITHUB_ENV as multiline
{
  echo "RELEASE_BODY<<EOREL"
  echo "$BODY"
  echo "EOREL"
} >> "${GITHUB_ENV:-/dev/null}"

echo "[OK] Release body generated"
