#!/usr/bin/env bash
# check-sources.sh - fetch upstream heads and compare against source-pins.json
set -e

PINS_FILE="sources/source-pins.json"

# Safe curl wrapper - never fails the script
_curl() { curl -sL --retry 3 --retry-delay 2 "$@" || echo ""; }

# Read a value from source-pins.json
_pin() { jq -r ".${1} // \"unknown\"" "$PINS_FILE" 2>/dev/null || echo "unknown"; }

# Return the highest valid tag name. Tag names are informational only.
_latest_tag() {
  local TAG
  TAG=$(_curl "$1" \
    | jq -r 'if type=="array" then .[] | .name? | select(type=="string" and length>0) else empty end' 2>/dev/null \
    | awk 'length($0) && $0 !~ /[[:space:]]/' \
    | LC_ALL=C sort -V \
    | tail -n 1)
  [ -n "$TAG" ] || TAG="unknown"
  printf '%s\n' "$TAG"
}

# Return a full commit SHA, or unknown when the query response is unusable.
_commit_sha() {
  local SHA
  SHA=$(_curl "$1" | jq -r "$2" 2>/dev/null || echo "")
  if [[ "$SHA" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf '%s\n' "$SHA"
  else
    printf '%s\n' "unknown"
  fi
}

echo "=== Fetching upstream sources ==="

KSUN_TAG=$(_latest_tag "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags")
echo "KSU-Next tag      : $KSUN_TAG (informational)"

SUKISU_BRANCH="${SUKISU_BRANCH:-builtin}"
SUKISU_BRANCH_PATH=$(jq -rn --arg branch "$SUKISU_BRANCH" '$branch|@uri')

SKSU_TAG=$(_latest_tag \
  "https://git.zako.shirkneko.top:20004/api/v1/repos/shirkneko/SukiSU/tags")
if [ "$SKSU_TAG" = "unknown" ]; then
  echo "[WARN] SukiSU Nova Forgejo tags unavailable; falling back to GitHub"
  SKSU_TAG=$(_latest_tag \
    "https://api.github.com/repos/SukiSU-Nova/SukiSU-Nova/tags")
fi
echo "SukiSU Nova tag  : $SKSU_TAG (informational)"

SUSFS_TAG=$(_latest_tag "https://api.github.com/repos/sidex15/susfs4ksu-module/tags")
echo "SUSFS module tag  : $SUSFS_TAG (informational)"

KSUN_COMMIT=$(_commit_sha \
  "https://api.github.com/repos/pershoot/KernelSU-Next/commits/dev-susfs" ".sha")
echo "KSU-Next HEAD     : $KSUN_COMMIT"

SKSU_COMMIT=$(_commit_sha \
  "https://git.zako.shirkneko.top:20004/api/v1/repos/shirkneko/SukiSU/branches/${SUKISU_BRANCH_PATH}" \
  ".commit.id")
if [ "$SKSU_COMMIT" = "unknown" ]; then
  echo "[WARN] SukiSU Nova Forgejo branch query failed; falling back to GitHub"
  SKSU_COMMIT=$(_commit_sha \
    "https://api.github.com/repos/SukiSU-Nova/SukiSU-Nova/commits/${SUKISU_BRANCH_PATH}" \
    ".sha")
fi
echo "SukiSU Nova HEAD : $SKSU_COMMIT"

SUSFS_COMMIT=$(_commit_sha \
  "https://gitlab.com/api/v4/projects/simonpunk%2Fsusfs4ksu/repository/commits/gki-android13-5.15" ".id")
echo "SUSFS HEAD        : $SUSFS_COMMIT"

GKI_TMP=$(mktemp -d)
git clone --filter=blob:none --sparse --depth=1 \
  https://android.googlesource.com/kernel/common \
  -b android13-5.15-lts "$GKI_TMP" >/dev/null 2>&1 && \
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
echo "GKI 5.15     : $GKI_SUB"


echo ""
echo "=== Comparing against source-pins.json ==="

PIN_GKI=$(_pin "gki_sublevel")
PIN_KSUN=$(_pin "ksun_tag")
PIN_SKSU=$(_pin "sksu_tag")
PIN_SUSFS=$(_pin "susfs_tag")
PIN_KSUN_COMMIT=$(_pin "ksun_commit")
PIN_SKSU_COMMIT=$(_pin "sksu_commit")
PIN_SUSFS_COMMIT=$(_pin "susfs_commit")

echo "Pinned KSU-Next HEAD     : ${PIN_KSUN_COMMIT:-empty}"
echo "Pinned SukiSU Nova HEAD : ${PIN_SKSU_COMMIT:-empty}"
echo "Pinned SUSFS HEAD        : ${PIN_SUSFS_COMMIT:-empty}"

UPDATES=()
FAILED=()

# A failed query reports the literal string "unknown" (see _curl/awk fallbacks
# above). That is a signal this run could not reach upstream, not a real value.
# Keep the last known-good pin on failure and report it separately instead of
# treating it as an update.
if [ "$GKI_SUB" = "unknown" ]; then
  FAILED+=("GKI"); GKI_SUB="$PIN_GKI"
elif [ "$GKI_SUB" != "$PIN_GKI" ]; then
  UPDATES+=("GKI: ${PIN_GKI} -> ${GKI_SUB}")
fi


KSUN_CHANGED="false"
SKSU_CHANGED="false"
SUSFS_CHANGED="false"

# Tag names are informational. A tag lookup failure does not hide a real commit
# update, but a successful tag lookup never creates one by itself.
if [ "$KSUN_TAG" = "unknown" ]; then
  FAILED+=("KSU-Next tag"); KSUN_TAG="$PIN_KSUN"
fi
if [ "$SKSU_TAG" = "unknown" ]; then
  FAILED+=("SukiSU Nova tag"); SKSU_TAG="$PIN_SKSU"
fi
if [ "$SUSFS_TAG" = "unknown" ]; then
  FAILED+=("SUSFS tag"); SUSFS_TAG="$PIN_SUSFS"
fi

if [ "$KSUN_COMMIT" = "unknown" ]; then
  FAILED+=("KSU-Next commit"); KSUN_COMMIT="$PIN_KSUN_COMMIT"
elif [ "$KSUN_COMMIT" != "$PIN_KSUN_COMMIT" ]; then
  UPDATES+=("KSU-Next: ${PIN_KSUN_COMMIT:-empty} -> ${KSUN_COMMIT}")
  KSUN_CHANGED="true"
fi

if [ "$SKSU_COMMIT" = "unknown" ]; then
  FAILED+=("SukiSU Nova commit"); SKSU_COMMIT="$PIN_SKSU_COMMIT"
elif [ "$SKSU_COMMIT" != "$PIN_SKSU_COMMIT" ]; then
  UPDATES+=("SukiSU Nova: ${PIN_SKSU_COMMIT:-empty} -> ${SKSU_COMMIT}")
  SKSU_CHANGED="true"
fi

if [ "$SUSFS_COMMIT" = "unknown" ]; then
  FAILED+=("SUSFS commit"); SUSFS_COMMIT="$PIN_SUSFS_COMMIT"
elif [ "$SUSFS_COMMIT" != "$PIN_SUSFS_COMMIT" ]; then
  UPDATES+=("SUSFS: ${PIN_SUSFS_COMMIT:-empty} -> ${SUSFS_COMMIT}")
  SUSFS_CHANGED="true"
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "[WARN] Could not fetch (kept last known-good pin): ${FAILED[*]}"
fi
FAILED_DETAIL=$(printf '%s\n' "${FAILED[@]}")

if [ ${#UPDATES[@]} -gt 0 ]; then
  echo "Updates detected:"
  for U in "${UPDATES[@]}"; do echo "  - $U"; done
  HAS_UPDATE="true"
  UPDATE_DETAIL=$(printf '%s\n' "${UPDATES[@]}")
else
  echo "All sources up to date."
  HAS_UPDATE="false"
  UPDATE_DETAIL=""
fi

# Job-level outputs - consumed cross-job by check-updates.yml (verify gate +
# apply-pins). Multi-line values use the same <<EOF heredoc syntax GITHUB_ENV
# uses; GITHUB_OUTPUT supports it identically.
{
  echo "ksun_tag=$KSUN_TAG"
  echo "sksu_tag=$SKSU_TAG"
  echo "susfs_tag=$SUSFS_TAG"
  echo "ksun_commit=$KSUN_COMMIT"
  echo "sksu_commit=$SKSU_COMMIT"
  echo "susfs_commit=$SUSFS_COMMIT"
  echo "gki_sub=$GKI_SUB"
  echo "has_update=$HAS_UPDATE"
  echo "ksun_changed=$KSUN_CHANGED"
  echo "sksu_changed=$SKSU_CHANGED"
  echo "susfs_changed=$SUSFS_CHANGED"
  echo "update_detail<<EOF"
  echo "$UPDATE_DETAIL"
  echo "EOF"
  echo "check_failed<<EOF"
  echo "$FAILED_DETAIL"
  echo "EOF"
} >> "${GITHUB_OUTPUT:-/dev/null}"

echo "=== Done ==="
