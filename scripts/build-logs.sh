#!/usr/bin/env bash
# build-logs.sh — collect per-job build logs into a zip (full raw job logs via GitHub API)
# env: GH_TOKEN, BUILD_TYPE, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_NUMBER, GITHUB_SHA
set -e

: "${BUILD_TYPE:-stable}"

mkdir -p ./audit_logs

gh api /repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs \
  --jq '.jobs[] | select(.name | test("GKI|CLO")) | [.id, .name] | @tsv' \
  > /tmp/build_jobs.tsv

_clean_log() {
  sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]*Z //' \
  | sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b(B//g' \
  | sed '/^##\[group\]/d; /^##\[endgroup\]/d'
}

_fetch_job_log() {
  local job_id="$1"
  local out="$2"
  local attempt
  for attempt in 1 2 3 4 5; do
    if gh api "/repos/${GITHUB_REPOSITORY}/actions/jobs/${job_id}/logs" 2>/dev/null | _clean_log > "$out.tmp"; then
      if [ -s "$out.tmp" ]; then
        mv "$out.tmp" "$out"
        return 0
      fi
    fi
    sleep 5
  done
  echo "[WARN] empty/failed log after 5 attempts: job $job_id" > "$out"
  rm -f "$out.tmp"
  return 1
}

while IFS=$'\t' read -r JOB_ID JOB_NAME; do
  SAFE=$(echo "$JOB_NAME" | sed 's|.* / ||' | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g; s/^_//; s/_$//')
  _fetch_job_log "$JOB_ID" "./audit_logs/${SAFE}.log"
done < /tmp/build_jobs.tsv

cat > ./audit_logs/00_run_info.txt << RUNINFO
Run    : #${GITHUB_RUN_NUMBER}
Repo   : ${GITHUB_REPOSITORY}
SHA    : ${GITHUB_SHA}
Date   : $(date -u +'%Y-%m-%d %H:%M:%S UTC')
Type   : ${BUILD_TYPE}
URL    : https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
RUNINFO

LOG_DATE=$(date -u +'%Y-%m-%d')
LOG_ZIP="build-log-run${GITHUB_RUN_NUMBER}-${LOG_DATE}-${BUILD_TYPE}.zip"
zip -r9 "$LOG_ZIP" audit_logs/
LOG_SIZE_MB=$(echo "scale=2; $(stat -c%s "$LOG_ZIP") / 1024 / 1024" | bc | sed 's/^\./0./')

echo "LOG_ZIP=$LOG_ZIP"         >> "${GITHUB_ENV:-/dev/null}"
echo "LOG_SIZE_MB=$LOG_SIZE_MB" >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Build log: $LOG_ZIP (${LOG_SIZE_MB} MB)"
