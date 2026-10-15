#!/usr/bin/env bash
# fetch-manager-apks.sh — pull the KernelSU-Next manager APK(s) from upstream CI
# and stage them in ./manager_apks for the release.
#
# env: GITHUB_TOKEN, KSUN_MANAGER_ARTIFACT_ID, KSUN_MANAGER_SPOOFED_ARTIFACT_ID
#
# A missing/expired artifact is a warning, never a failed release: the APK is a
# convenience copy of something the release body already links to.
set -e

KSUN_REPO="KernelSU-Next/KernelSU-Next"

mkdir -p ./manager_apks

_fetch() {
  local artifact_id="$1" label="$2"
  if [ -z "$artifact_id" ]; then
    echo "[SKIP] No artifact ID for $label"
    return 0
  fi

  local tmp="/tmp/mgr_${label}"
  rm -rf "$tmp" && mkdir -p "$tmp"

  local attempt ok=0
  for attempt in 1 2 3; do
    if curl -sfL --max-time 60 \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${KSUN_REPO}/actions/artifacts/${artifact_id}/zip" \
      -o "${tmp}/artifact.zip"; then
      ok=1
      break
    fi
    echo "[WARN] Fetch attempt ${attempt}/3 failed for $label — retrying in 5s"
    sleep 5
  done
  if [ "$ok" -ne 1 ]; then
    echo "[WARN] Fetch failed for $label after 3 attempts — skipping"
    return 0
  fi

  unzip -j "${tmp}/artifact.zip" "*.apk" -d "${tmp}/" 2>/dev/null \
    || { echo "[WARN] No APK in $label artifact — skipping"; return 0; }

  local apk
  # Prefer arm64-v8a, then universal, then whatever landed.
  apk=$(find "${tmp}" -name "*arm64-v8a*.apk" | head -1)
  [ -z "$apk" ] && apk=$(find "${tmp}" -name "*universal*.apk" | head -1)
  [ -z "$apk" ] && apk=$(find "${tmp}" -name "*.apk" | head -1)
  [ -z "$apk" ] && { echo "[WARN] APK not found post-extract for $label"; return 0; }

  local apk_name
  apk_name=$(basename "$apk")

  # The spoofed manager ships the same filename as the normal one — make the two
  # distinguishable in the release asset list.
  case "$label" in
    *-spoofed)
      case "$apk_name" in
        *release.apk) apk_name="${apk_name/-release.apk/-spoofed-release.apk}" ;;
        *debug.apk)   apk_name="${apk_name/-debug.apk/-spoofed-debug.apk}" ;;
        *)            apk_name="Spoofed-${apk_name}" ;;
      esac
      ;;
  esac

  local dest="./manager_apks/${apk_name}"
  if [ -e "$dest" ]; then
    echo "[WARN] Filename collision for $label: ${apk_name} already fetched — skipping"
    return 0
  fi

  cp "$apk" "$dest"
  echo "[OK] ${apk_name} ($(du -h "$dest" | cut -f1))"
}

_fetch "${KSUN_MANAGER_ARTIFACT_ID:-}"         "ksun"
_fetch "${KSUN_MANAGER_SPOOFED_ARTIFACT_ID:-}" "ksun-spoofed"

ls -1 ./manager_apks/ 2>/dev/null || true
