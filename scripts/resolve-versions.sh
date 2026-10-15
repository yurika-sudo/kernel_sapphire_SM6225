#!/usr/bin/env bash
# resolve-versions.sh — turn the build's version records + upstream APIs into
# the variables the release steps need (tag, name, manager links, notes data).
#
# env: BUILD_TYPE, GITHUB_REPOSITORY, GITHUB_TOKEN (optional — public repos read
#      fine unauthenticated, and sending an empty token only gets a 401)
#      (the build's *.txt version records are read back from ./artifacts)
#
# Everything degrades to the pinned value in sources/source-pins.json when a
# lookup fails, so a flaky API never produces "unknown" in a release body.
set -e

: "${BUILD_TYPE:-stable}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PINS_FILE="${PINS_FILE:-$SCRIPT_DIR/../sources/source-pins.json}"
_gh() {   # curl with the auth header only when a token is present
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -sf --max-time 20 -H "Authorization: Bearer ${GITHUB_TOKEN}" "$@"
  else
    curl -sf --max-time 20 "$@"
  fi
}

_pin() {
  local V
  V=$(jq -r ".${1} // empty" "$PINS_FILE" 2>/dev/null || true)
  echo "${V:-${2:-unknown}}"
}

_read_rec() {  # <file> <fallback> — records come back inside the build artifact
  local F V=""
  F=$(find ./artifacts -name "$1" 2>/dev/null | head -1)
  [ -n "$F" ] && [ -f "$F" ] && V=$(tr -d '[:space:]' < "$F")
  echo "${V:-$2}"
}

# ---------------------------------------------------------------------------
# Kernel + KSU/SUSFS versions
# ---------------------------------------------------------------------------
VERSION_FILE=$(find ./artifacts -name "kernel_version.txt" | head -1)
KERNEL_VERSION=$([ -f "$VERSION_FILE" ] && tr -d '[:space:]' < "$VERSION_FILE" || echo "5.15.x")

UNAME_FILE=$(find ./artifacts -name "kernel_uname.txt" | head -1)
KERNEL_UNAME=$([ -f "$UNAME_FILE" ] && tr -d '[:space:]' < "$UNAME_FILE" || echo "$KERNEL_VERSION")

KSUN_TAG=$(_read_rec ksun_tag.txt        "$(_pin ksun_tag unknown)")
KSUN_SHA=$(_read_rec ksun_sha.txt        "")
KSUN_BASE_SHA=$(_read_rec ksun_base_sha.txt "")
KSUN_VERSION=$(_read_rec ksun_version.txt "")
SUSFS_VERSION=$(_read_rec susfs_version.txt "$(_pin susfs_version unknown)")
SUSFS_COMMIT=$(_read_rec susfs_commit.txt "")

SUSFS_MODULE_VERSION=$(_pin susfs_module_tag "")
DROIDSPACES_VERSION=$(_pin droidspaces_tag "")

# ---------------------------------------------------------------------------
# Manager build that matches this kernel
#
# The kernel's KSU version code is 30000 + <commits on the base branch up to the
# merge-base of the fork branch> (that is how KernelSU-Next's Kbuild derives it),
# so the manager APK that matches is the CI build of that *merge-base commit*,
# not the newest manager on dev. A newer manager against an older kernel is what
# shows up on the device as "Failed to update App Profile".
# Order: merge-base sha → driver sha → latest successful run.
# ---------------------------------------------------------------------------
KSUN_MANAGER_URL=""
KSUN_MANAGER_ARTIFACT_ID=""
KSUN_MANAGER_SPOOFED_ARTIFACT_ID=""

_ksun_find_run() {
  local SHA="$1" page runs run_id count
  [ -n "$SHA" ] || return 0
  for page in 1 2 3; do
    runs=$(_gh \
      "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/actions/workflows/build-manager-ci.yml/runs?status=success&branch=dev&per_page=20&page=${page}" \
      || true)
    [ -n "$runs" ] || return 0
    run_id=$(echo "$runs" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sha = sys.argv[1].lower()
for r in d.get("workflow_runs", []):
    if r.get("head_sha", "").lower().startswith(sha):
        print(r["id"]); break
' "$SHA" 2>/dev/null | tr -d '[:space:]')
    [ -n "$run_id" ] && { echo "$run_id"; return 0; }
    count=$(echo "$runs" | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("workflow_runs",[])))' 2>/dev/null || echo 0)
    [ "${count:-0}" -lt 20 ] && break
  done
  return 0
}

_latest_ksun_run() {
  _gh "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/actions/workflows/build-manager-ci.yml/runs?status=success&branch=dev&per_page=1" \
    | python3 -c 'import sys,json
try:
    d = json.load(sys.stdin)
    runs = d.get("workflow_runs", [])
    print(runs[0]["id"] if runs else "")
except Exception:
    print("")' 2>/dev/null || true
}

# Candidate order: the commit the kernel's version code derives from, then the
# driver HEAD, then the newest successful run. A candidate only wins if it still
# has a downloadable "manager" artifact — CI artifacts expire, and a release
# asset that 410s is worse than a manager build a few commits newer.
for _SHA in "$KSUN_BASE_SHA" "$KSUN_SHA" ""; do
  if [ -n "$_SHA" ]; then
    _KRUN=$(_ksun_find_run "$_SHA")
  else
    _KRUN=$(_latest_ksun_run)
  fi
  [ -n "$_KRUN" ] || continue
  _ARTS=$(_gh "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/actions/runs/${_KRUN}/artifacts" || true)
  _ID=$(echo "$_ARTS" | jq -r '.artifacts[] | select(.name=="manager") | select(.expired==false) | .id // empty' 2>/dev/null | head -1 || true)
  [ -n "$_ID" ] || continue
  KSUN_MANAGER_URL="https://github.com/KernelSU-Next/KernelSU-Next/actions/runs/${_KRUN}"
  KSUN_MANAGER_ARTIFACT_ID="$_ID"
  KSUN_MANAGER_SPOOFED_ARTIFACT_ID=$(echo "$_ARTS" \
    | jq -r '.artifacts[] | select(.name=="manager-spoofed") | select(.expired==false) | .id // empty' 2>/dev/null | head -1 || true)
  [ -n "$_SHA" ] && echo "[OK] Manager CI build matched ${_SHA:0:12}"
  break
done

if [ -z "$KSUN_MANAGER_ARTIFACT_ID" ]; then
  echo "[WARN] No usable manager CI build found (kernel base ${KSUN_BASE_SHA:-?} / head ${KSUN_SHA:-?}) — linking the workflow page instead"
fi
KSUN_MANAGER_URL="${KSUN_MANAGER_URL:-https://github.com/KernelSU-Next/KernelSU-Next/actions/workflows/build-manager-ci.yml}"

# ---------------------------------------------------------------------------
# Release identity
# ---------------------------------------------------------------------------
RELEASE_NAME="Seiran-GKI"

if [ -z "$SUSFS_MODULE_VERSION" ] || [ "$SUSFS_MODULE_VERSION" = "unknown" ]; then
  echo "[ERROR] SUSFS module version unresolved — refusing to publish a release tagged 'unknown'." >&2
  echo "        Check sources/source-pins.json (susfs_module_tag) and the API above." >&2
  exit 1
fi

if [ "$BUILD_TYPE" = "testing" ]; then
  RELEASE_TAG="${SUSFS_MODULE_VERSION}-testing"
  IS_PRERELEASE="true"
else
  RELEASE_TAG="$SUSFS_MODULE_VERSION"
  IS_PRERELEASE="false"
fi

ENCODED_TAG=$(printf '%s' "$RELEASE_TAG" | sed 's/+/%2B/g')
RELEASE_URL="https://github.com/${GITHUB_REPOSITORY}/releases/tag/${ENCODED_TAG}"

{
  echo "KSUN_TAG=$KSUN_TAG"
  echo "KSUN_VERSION=$KSUN_VERSION"
  echo "KSUN_SHA=$KSUN_SHA"
  echo "SUSFS_VERSION=$SUSFS_VERSION"
  echo "SUSFS_COMMIT=$SUSFS_COMMIT"
  echo "SUSFS_MODULE_VERSION=$SUSFS_MODULE_VERSION"
  echo "DROIDSPACES_VERSION=$DROIDSPACES_VERSION"
  echo "KSUN_MANAGER_URL=$KSUN_MANAGER_URL"
  echo "KSUN_MANAGER_ARTIFACT_ID=$KSUN_MANAGER_ARTIFACT_ID"
  echo "KSUN_MANAGER_SPOOFED_ARTIFACT_ID=$KSUN_MANAGER_SPOOFED_ARTIFACT_ID"
  echo "KERNEL_VERSION=$KERNEL_VERSION"
  echo "KERNEL_UNAME=$KERNEL_UNAME"
  echo "RELEASE_TAG=$RELEASE_TAG"
  echo "RELEASE_NAME=$RELEASE_NAME"
  echo "IS_PRERELEASE=$IS_PRERELEASE"
  echo "RELEASE_URL=$RELEASE_URL"
  echo "SUSFS_MODULE_URL=https://github.com/$(_pin susfs_module_repo sidex15/susfs4ksu-module)/releases/latest"
} >> "${GITHUB_ENV:-/dev/null}"

echo "[OK] Versions resolved"
echo "  Kernel  : $KERNEL_UNAME"
echo "  KSU-Next: $KSUN_TAG (code ${KSUN_VERSION:-?})"
echo "  SUSFS   : $SUSFS_VERSION kernel-side, module $SUSFS_MODULE_VERSION"
echo "  DroidSp : $DROIDSPACES_VERSION"
echo "  Tag     : $RELEASE_TAG"
