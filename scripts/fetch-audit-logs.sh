#!/usr/bin/env bash
# fetch-audit-logs.sh — fetch full runner logs from a completed run, zip, upload to release
# env: GH_TOKEN, TRIGGERED_RUN_ID, GITHUB_REPOSITORY, BUILD_TYPE
# Called from fetch-logs.yml after build-aio.yml completes (different run = API not blocked)
set -e

: "${TRIGGERED_RUN_ID:?}"
: "${GITHUB_REPOSITORY:?}"
: "${BUILD_TYPE:-stable}"

mkdir -p ./audit_logs

# Strip ISO timestamp prefix and ANSI escape codes — identical to original audit-logs.sh
_clean_log() {
  sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]*Z //' \
  | sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b(B//g' \
  | sed '/^##\[group\]/d; /^##\[endgroup\]/d'
}

echo "[INFO] Fetching job list for run ${TRIGGERED_RUN_ID}..."
gh api /repos/${GITHUB_REPOSITORY}/actions/runs/${TRIGGERED_RUN_ID}/jobs \
  --jq '.jobs[] | select(.name | test("GKI|CLO")) | [.id, .name] | @tsv' \
  > /tmp/build_jobs.tsv

if [ ! -s /tmp/build_jobs.tsv ]; then
  echo "[WARN] No GKI/CLO jobs found in run ${TRIGGERED_RUN_ID}"
  exit 0
fi

found=0
while IFS=$'\t' read -r JOB_ID JOB_NAME; do
  SAFE=$(echo "$JOB_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g; s/__*/_/g; s/^_//; s/_$//')
  echo "[FETCH] ${JOB_NAME} (${JOB_ID})..."
  curl -sfL \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/jobs/${JOB_ID}/logs" \
    2>/dev/null \
    | _clean_log \
    > "./audit_logs/${SAFE}.log" \
    || { echo "[WARN] fetch failed for ${JOB_NAME}"; echo "[WARN] fetch failed" > "./audit_logs/${SAFE}.log"; }
  echo "[OK] ${JOB_NAME} ($(wc -l < "./audit_logs/${SAFE}.log") lines)"
  found=$((found + 1))
done < /tmp/build_jobs.tsv

# Run info header
RUN_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${TRIGGERED_RUN_ID}"
cat > ./audit_logs/00_run_info.txt << RUNINFO
Run    : (triggered by run ${TRIGGERED_RUN_ID})
Repo   : ${GITHUB_REPOSITORY}
Date   : $(date -u +'%Y-%m-%d %H:%M:%S UTC')
Type   : ${BUILD_TYPE}
URL    : ${RUN_URL}
RUNINFO

[ "$BUILD_TYPE" = "testing" ] && SUFFIX="-testing" || SUFFIX=""
LOG_ZIP="build-audit-logs-$(date +'%Y-%m')${SUFFIX}.zip"
zip -r9 "$LOG_ZIP" audit_logs/
LOG_SIZE_MB=$(echo "scale=2; $(stat -c%s "$LOG_ZIP") / 1024 / 1024" | bc | sed 's/^\./0./')
echo "[OK] ${LOG_ZIP} (${LOG_SIZE_MB} MB, ${found} variants)"

# Resolve release tag — same logic as resolve-versions.sh
SUSFS_TAG=$(jq -r '.susfs_tag // empty' sources/source-pins.json 2>/dev/null || echo "")
if [ -z "$SUSFS_TAG" ]; then
  echo "[WARN] Could not resolve release tag from source-pins.json — skipping upload"
  exit 0
fi
[ "$BUILD_TYPE" = "testing" ] && RELEASE_TAG="${SUSFS_TAG}-testing" || RELEASE_TAG="$SUSFS_TAG"

echo "[INFO] Uploading to release ${RELEASE_TAG}..."
GH_TOKEN="$GITHUB_TOKEN" gh release upload "$RELEASE_TAG" "$LOG_ZIP" \
  --repo "$GITHUB_REPOSITORY" \
  --clobber \
  && echo "[OK] Uploaded ${LOG_ZIP} to ${RELEASE_TAG}" \
  || echo "[WARN] Upload failed — release ${RELEASE_TAG} may not exist yet"
