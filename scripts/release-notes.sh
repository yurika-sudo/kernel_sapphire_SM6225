#!/usr/bin/env bash
# release-notes.sh — generate the release body (RELEASE_BODY in $GITHUB_ENV)
#
# env: BUILD_TYPE, REPO, SHA, RUN_URL, GITHUB_RUN_NUMBER,
#      KERNEL_VERSION, KERNEL_UNAME, KSUN_TAG, KSUN_VERSION, SUSFS_VERSION,
#      SUSFS_COMMIT, SUSFS_MODULE_VERSION, SUSFS_MODULE_URL, DROIDSPACES_VERSION,
#      KSUN_MANAGER_URL
set -e

: "${BUILD_TYPE:-stable}"
: "${RUN_URL:?}"
: "${REPO:?}"
: "${SHA:?}"

SHORT_SHA="${SHA:0:9}"
COMMIT_URL="https://github.com/${REPO}/commit/${SHA}"
BODY=""

if [ "$BUILD_TYPE" = "testing" ]; then
  BODY="${BODY}> [!WARNING]"$'\n'
  BODY="${BODY}> Testing build — debug stripped, perf/sched configs non-default. Expect rough edges."$'\n\n'
fi

BODY="${BODY}**Kernel base:** \`${KERNEL_UNAME:-$KERNEL_VERSION}\`"$'\n'
BODY="${BODY}**KernelSU-Next:** \`${KSUN_TAG:-unknown}\` · version code \`${KSUN_VERSION:-?}\`"$'\n'
BODY="${BODY}**SUSFS (in-tree):** \`${SUSFS_VERSION:-?}\`"$'\n'
BODY="${BODY}**SUSFS module:** [${SUSFS_MODULE_VERSION:-latest}](${SUSFS_MODULE_URL})"$'\n'
BODY="${BODY}**DroidSpaces:** \`${DROIDSPACES_VERSION:-?}\` ready (SYSVIPC kABI padded, USER_NS, macvlan, overlayfs)"$'\n\n'

BODY="${BODY}**KSU-Next Manager:** [matching CI build ↗](${KSUN_MANAGER_URL:-https://github.com/KernelSU-Next/KernelSU-Next/actions/workflows/build-manager-ci.yml})"$'\n'
BODY="${BODY}**Seiran Core module (required for ZRAM):** \`seiran-core.zip\` — attached below & on [Telegram](https://t.me/tmplogchat)"$'\n\n'

BODY="${BODY}**Target:** GKI \`android13-5.15-lts\` · KernelSU-Next + built-in SUSFS · Android 15+ ROMs"$'\n'
BODY="${BODY}**ROM:** AOSP-based recommended — stock MIUI/HyperOS may have issues"$'\n'
BODY="${BODY}**Issues:** [t.me/home_yu_chat](https://t.me/home_yu_chat) · Critical → PM directly"$'\n\n'

BODY="${BODY}> [!IMPORTANT]"$'\n'
BODY="${BODY}> **The manager app must match the kernel's version code above.** A newer manager against this kernel is what shows up on the device as \`Failed to update App Profile\` or root never being granted — use the CI link above, not the stable release."$'\n\n'

BODY="${BODY}> [!NOTE]"$'\n'
BODY="${BODY}> Flashing via recovery or a kernel flasher app. **Magisk users: re-patch boot after flashing.** Install \`seiran-core.zip\` afterwards — \`CONFIG_ZRAM=m\` means ZRAM only works once that module is installed."$'\n\n'

BODY="${BODY}**Commit:** [\`${SHORT_SHA}\`](${COMMIT_URL})"$'\n'
BODY="${BODY}📋 **Per-build details:** [Run #${GITHUB_RUN_NUMBER} summary](${RUN_URL})"

{
  echo "RELEASE_BODY<<EOREL"
  echo "$BODY"
  echo "EOREL"
} >> "${GITHUB_ENV:-/dev/null}"

echo "[OK] Release body generated"
