#!/usr/bin/env bash
# fetch-manager-apks.sh — pull manager APK from upstream CI artifact, attach to release
# env: GITHUB_TOKEN, KSUN_MANAGER_ARTIFACT_ID, SUKI_MANAGER_ARTIFACT_ID, KSUN_VERSION, SUKI_VERSION
set -e

mkdir -p ./manager_apks

_fetch() {
  local repo="$1" artifact_id="$2" out_name="$3"
  if [ -z "$artifact_id" ]; then
    echo "[SKIP] No artifact ID for $out_name"
    return 0
  fi

  local tmp="/tmp/mgr_${out_name}"
  mkdir -p "$tmp"

  curl -sfL --max-time 60 --location \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${repo}/actions/artifacts/${artifact_id}/zip" \
    -o "${tmp}/artifact.zip" || { echo "[WARN] Fetch failed for $out_name — skipping"; return 0; }

  unzip -j "${tmp}/artifact.zip" "*.apk" -d "${tmp}/" 2>/dev/null \
    || { echo "[WARN] No APK in $out_name artifact — skipping"; return 0; }

  local apk
  apk=$(find "${tmp}" -name "*.apk" | head -1)
  [ -z "$apk" ] && { echo "[WARN] APK not found post-extract for $out_name"; return 0; }

  cp "$apk" "./manager_apks/${out_name}.apk"
  echo "[OK] ${out_name}.apk ($(du -h "./manager_apks/${out_name}.apk" | cut -f1))"
}

_fetch "KernelSU-Next/KernelSU-Next" "${KSUN_MANAGER_ARTIFACT_ID:-}" "KSU-Next-manager-${KSUN_VERSION:-ci}"
_fetch "SukiSU-Ultra/SukiSU-Ultra"   "${SUKI_MANAGER_ARTIFACT_ID:-}" "SukiSU-manager-${SUKI_VERSION:-ci}"
