#!/usr/bin/env bash
# check-sources.sh — fetch the latest upstream versions and compare them with
# sources/source-pins.json. Run by .github/workflows/check-updates.yml, which
# builds a verification kernel before the new pins are committed.
#
# Outputs (via $GITHUB_OUTPUT) — see the workflow for how they are consumed.
#
# Design notes:
#   * A fetch that fails reports the literal "unknown"; that must never be
#     compared as if it were a version, or a flaky run would push "unknown" into
#     the pin file. Failed lookups keep the last known-good value and are
#     surfaced separately in check_failed.
#   * KernelSU-Next *floats* on pershoot's dev-susfs branch (only that branch
#     carries the built-in-SUSFS integration), so the upstream tag we record is
#     a marker for the verify gate, not a checkout we build from. The fork's
#     branch HEAD is reported too, so a fork-only movement is visible.
set -e

PINS_FILE="sources/source-pins.json"

_out()      { echo "$1=$2" >> "${GITHUB_OUTPUT:-/dev/null}"; }
_pin()      { jq -r ".${1} // \"unknown\"" "$PINS_FILE" 2>/dev/null || echo "unknown"; }
_note()     { echo "$*"; }
_fail()     { FAILED+=("$1"); }

# Safe curl wrapper — never fails the script
_curl() { curl -sL --retry 3 --retry-delay 2 --max-time 45 "$@" || echo ""; }

KSUN_REPO=$(jq -r '.ksun_repo  // "pershoot/KernelSU-Next"'  "$PINS_FILE")
KSUN_BRANCH=$(jq -r '.ksun_branch // "dev-susfs"'           "$PINS_FILE")
SUSFS_REPO=$(jq -r '.susfs_repo // "gitlab.com/simonpunk/susfs4ksu"' "$PINS_FILE")
SUSFS_BRANCH=$(jq -r '.susfs_branch // "gki-android13-5.15"'        "$PINS_FILE")
SUSFS_MOD_REPO=$(jq -r '.susfs_module_repo // "sidex15/susfs4ksu-module"' "$PINS_FILE")
DS_REPO=$(jq -r '.droidspaces_repo // "ravindu644/Droidspaces-OSS"' "$PINS_FILE")
DS_PATCH_PATH="Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch"

UPDATES=()
FAILED=()

_neq() { [ "$1" != "$2" ]; }

# ---------------------------------------------------------------------------
# Latest release tag of a GitHub repo. releases/latest is authoritative for
# "what is the current release"; the tags API is not sorted by version and its
# first element can be a stale or out-of-order tag (KSU-Next publishes
# v3.4.2-legacy style tags next to v3.4.2).
# ---------------------------------------------------------------------------
_latest_release_tag() {
  local REPO="$1" TAG=""
  TAG=$(_curl "https://api.github.com/repos/${REPO}/releases/latest" \
        | jq -r 'if type=="object" then .tag_name // empty else empty end' 2>/dev/null)
  [ -n "$TAG" ] || TAG=$(_curl "https://api.github.com/repos/${REPO}/tags" \
        | jq -r 'if type=="array" then (.[0].name // empty) else empty end' 2>/dev/null)
  echo "${TAG:-unknown}"
}

echo "=== Fetching upstream sources ==="

# --- KernelSU-Next: upstream release tag + the branch we actually build from
KSUN_TAG=$(_latest_release_tag "KernelSU-Next/KernelSU-Next")
_neq "$KSUN_TAG" "" || KSUN_TAG="unknown"
_neq "$KSUN_TAG" "unknown" || _fail "KSU-Next release tag"
KSUN_HEAD=$(git ls-remote "https://github.com/${KSUN_REPO}.git" "refs/heads/${KSUN_BRANCH}" 2>/dev/null \
            | awk '{print substr($1,1,12)}')
KSUN_HEAD="${KSUN_HEAD:-unknown}"
_neq "$KSUN_HEAD" "unknown" || _fail "KSU-Next ${KSUN_BRANCH} head"
_note "KSU-Next     : $KSUN_TAG   (built from ${KSUN_REPO}@${KSUN_BRANCH}, head $KSUN_HEAD)"

# --- SUSFS kernel patch: gitlab branch HEAD + its SUSFS_VERSION
SUSFS_HEAD=$(git ls-remote "https://${SUSFS_REPO}.git" "refs/heads/${SUSFS_BRANCH}" 2>/dev/null \
             | awk '{print substr($1,1,12)}')
SUSFS_HEAD="${SUSFS_HEAD:-unknown}"
SUSFS_VER=$(_curl "https://${SUSFS_REPO}/-/raw/${SUSFS_BRANCH}/kernel_patches/include/linux/susfs.h" \
            | sed -n 's/^#define SUSFS_VERSION[[:space:]]*"\(.*\)".*/\1/p' | head -1)
SUSFS_VER="${SUSFS_VER:-unknown}"
if [ "$SUSFS_HEAD" = "unknown" ] || [ "$SUSFS_VER" = "unknown" ]; then
  _fail "SUSFS branch ${SUSFS_BRANCH}"
fi
_note "SUSFS patch  : $SUSFS_VER  ($SUSFS_REPO@${SUSFS_BRANCH}, head $SUSFS_HEAD)"

# --- SUSFS userspace module (the flashable ksu_susfs module / WebUI)
SUSFS_MOD_TAG=$(_latest_release_tag "$SUSFS_MOD_REPO")
SUSFS_MOD_TAG="${SUSFS_MOD_TAG:-unknown}"
_neq "$SUSFS_MOD_TAG" "unknown" || _fail "SUSFS module release tag"
_note "SUSFS module : $SUSFS_MOD_TAG"

# --- DroidSpaces release + the kABI patch this repo builds with must exist there
DS_TAG=$(_latest_release_tag "$DS_REPO")
DS_TAG="${DS_TAG:-unknown}"
_neq "$DS_TAG" "unknown" || _fail "DroidSpaces release tag"
# -w prints one code per attempt (redirects included) — the last one is the answer
DS_PATCH_OK=$(curl -sIL --max-time 45 -o /dev/null -w '%{http_code}\n' \
  "https://raw.githubusercontent.com/${DS_REPO}/refs/tags/${DS_TAG}/${DS_PATCH_PATH}" 2>/dev/null \
  | tail -1)
DS_PATCH_OK="${DS_PATCH_OK:-000}"
if [ "$DS_PATCH_OK" != "200" ]; then
  _fail "DroidSpaces kABI patch path (HTTP $DS_PATCH_OK at $DS_TAG)"
fi
_note "DroidSpaces  : $DS_TAG  (kABI patch reachable: $([ "$DS_PATCH_OK" = "200" ] && echo yes || echo NO))"

# --- GKI sublevel (Makefile of the branch we build)
GKI_TMP=$(mktemp -d)
git clone --filter=blob:none --sparse --depth=1 \
  https://android.googlesource.com/kernel/common \
  -b "$(jq -r '.gki_branch // "android13-5.15-lts"' "$PINS_FILE")" "$GKI_TMP" >/dev/null 2>&1 && \
git -C "$GKI_TMP" sparse-checkout set --cone >/dev/null 2>&1 && \
git -C "$GKI_TMP" checkout HEAD -- Makefile >/dev/null 2>&1 || true
GKI_SUB=$(awk -F' *= *' \
  '/^VERSION /    {v=$2}
   /^PATCHLEVEL / {p=$2}
   /^SUBLEVEL /   {s=$2}
   END { if(v && p && s) print "v"v"."p"."s; else print "unknown" }' \
  "$GKI_TMP/Makefile" 2>/dev/null || echo "unknown")
GKI_SUB="${GKI_SUB:-unknown}"
rm -rf "$GKI_TMP"
_neq "$GKI_SUB" "unknown" || _fail "GKI sublevel"
_note "GKI 5.15     : $GKI_SUB"

echo ""
echo "=== Comparing against source-pins.json ==="

KSUN_CHANGED="false"
SUSFS_CHANGED="false"
DS_CHANGED="false"

PIN_KSUN=$(_pin ksun_tag)
PIN_SUSFS=$(_pin susfs_version)
PIN_SUSFS_MOD=$(_pin susfs_module_tag)
PIN_DS=$(_pin droidspaces_tag)
PIN_GKI=$(_pin gki_sublevel)

# What triggers a bump is the *version*, never a raw commit sha: the KSU fork
# branch and the susfs branch both move more often than they release, the build
# floats on them anyway, and gating on every push would burn a verify build per
# upstream commit. The shas are logged for context.
if [ "$KSUN_TAG" = "unknown" ]; then
  KSUN_TAG="$PIN_KSUN"
elif [ "$KSUN_TAG" != "$PIN_KSUN" ]; then
  UPDATES+=("KSU-Next: ${PIN_KSUN} → ${KSUN_TAG} (branch head ${KSUN_HEAD})")
  KSUN_CHANGED="true"
fi

if [ "$SUSFS_VER" = "unknown" ]; then
  SUSFS_VER="$PIN_SUSFS"
elif [ "$SUSFS_VER" != "$PIN_SUSFS" ]; then
  UPDATES+=("SUSFS: ${PIN_SUSFS} → ${SUSFS_VER} (branch head ${SUSFS_HEAD})")
  SUSFS_CHANGED="true"
fi

if [ "$SUSFS_MOD_TAG" != "unknown" ] && [ "$SUSFS_MOD_TAG" != "$PIN_SUSFS_MOD" ]; then
  UPDATES+=("SUSFS module: ${PIN_SUSFS_MOD} → ${SUSFS_MOD_TAG}")
fi

if [ "$DS_TAG" = "unknown" ]; then
  DS_TAG="$PIN_DS"
elif [ "$DS_TAG" != "$PIN_DS" ]; then
  UPDATES+=("DroidSpaces: ${PIN_DS} → ${DS_TAG}")
  DS_CHANGED="true"
fi

if [ "$GKI_SUB" != "unknown" ] && [ "$GKI_SUB" != "$PIN_GKI" ]; then
  UPDATES+=("GKI: ${PIN_GKI} → ${GKI_SUB}")
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "[WARN] Could not fetch (kept last known-good pin): ${FAILED[*]}"
fi
FAILED_DETAIL=$(printf '%s\n' "${FAILED[@]}")

# Anything that changes what we compile is gated by a verify build; the GKI
# sublevel and the SUSFS module tag are not (they don't touch the KSU/SUSFS
# integration, and a kernel.org bump never breaks on its own).
NEEDS_VERIFY="false"
if [ "$KSUN_CHANGED" = "true" ] || [ "$SUSFS_CHANGED" = "true" ] || [ "$DS_CHANGED" = "true" ]; then
  NEEDS_VERIFY="true"
fi

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

# ---------------------------------------------------------------------------
# Job outputs — consumed cross-job by check-updates.yml (verify gate + apply-pins)
# ---------------------------------------------------------------------------
{
  echo "ksun_tag=$KSUN_TAG"
  echo "susfs_version=$SUSFS_VER"
  echo "susfs_module_tag=$SUSFS_MOD_TAG"
  echo "droidspaces_tag=$DS_TAG"
  echo "gki_sub=$GKI_SUB"
  echo "has_update=$HAS_UPDATE"
  echo "needs_verify=$NEEDS_VERIFY"
  echo "update_detail<<EOF"
  echo "$UPDATE_DETAIL"
  echo "EOF"
  echo "check_failed=$([ ${#FAILED[@]} -gt 0 ] && echo true || echo false)"
  echo "check_failed_detail<<EOF"
  echo "$FAILED_DETAIL"
  echo "EOF"
} >> "${GITHUB_OUTPUT:-/dev/null}"

echo "=== Done ==="
