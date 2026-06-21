#!/usr/bin/env bash
# release-notes.sh — generate release body
set -e

: "${BUILD_TYPE:-stable}"
: "${WORKFLOW_TYPE:-aio}"
: "${RUN_URL:?}"
: "${REPO:?}"
: "${SHA:?}"

SHORT_SHA="${SHA:0:9}"
COMMIT_URL="https://github.com/${REPO}/commit/${SHA}"
BODY=""

# Compat restriction banner
if [ "$WORKFLOW_TYPE" = "compat" ]; then
  BODY="${BODY}> [!CAUTION]"$'\n'
  BODY="${BODY}> GKI-Compat is for **Android 13 / 14 only**. Flashing on A15+ = bootloop. Use main [Seiran-GKI](https://github.com/${REPO}/releases/latest) for A15+."$'\n\n'
fi

# Testing warning banner
if [ "$BUILD_TYPE" = "testing" ]; then
  BODY="${BODY}> [!WARNING]"$'\n'
  BODY="${BODY}> Testing build — debug stripped, perf/sched configs non-default. Expect rough edges."$'\n\n'
fi

BODY="${BODY}**KSU-Next:** [${KSUN_TAG}](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/${KSUN_TAG})"$'\n'
BODY="${BODY}**SukiSU-Ultra:** [${SUKI_TAG}](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases/tag/${SUKI_TAG})"$'\n'
BODY="${BODY}**SUSFS module:** [${SUSFS_VERSION}](${SUSFS_MODULE_URL})"$'\n'
BODY="${BODY}**Kernel base:** \`${KERNEL_VERSION}\`"$'\n\n'

if [ "$WORKFLOW_TYPE" = "compat" ]; then
  BODY="${BODY}**Variants:** GKI-Compat (KSU-Next · SukiSU · NoKSU)"$'\n'
  BODY="${BODY}**Supported:** Android 13 / 14"$'\n'
else
  BODY="${BODY}**Variants:** GKI (KSU-Next · SukiSU · NoKSU) · CLO (KSU-Next · SukiSU · NoKSU)"$'\n'
  BODY="${BODY}**Supported:** Android 15+"$'\n'
fi
BODY="${BODY}**ROM:** AOSP-based recommended — stock MIUI/HyperOS may have issues"$'\n'
BODY="${BODY}**Issues:** [t.me/home_yu_chat](https://t.me/home_yu_chat) · Critical → PM directly"$'\n\n'

# Compat manager known issue
if [ "$WORKFLOW_TYPE" = "compat" ]; then
  BODY="${BODY}> [!IMPORTANT]"$'\n'
  BODY="${BODY}> Manager shows \"Failed to update App Profile\"? Update to latest CI manager → [get it here](https://t.me/tmplogchat/310)"$'\n\n'
fi

BODY="${BODY}**Commit:** [\`${SHORT_SHA}\`](${COMMIT_URL})"$'\n'
BODY="${BODY}📋 **Per-build details:** [Run #${GITHUB_RUN_NUMBER} summary](${RUN_URL})"$'\n'
BODY="${BODY}> Full build logs in \`build-audit-logs-*.zip\` below."

{
  echo "RELEASE_BODY<<EOREL"
  echo "$BODY"
  echo "EOREL"
} >> "${GITHUB_ENV:-/dev/null}"

echo "[OK] Release body generated"
