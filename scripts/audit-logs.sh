#!/usr/bin/env bash
# audit-logs.sh — collect per-job build logs into a zip
# env: GH_TOKEN, DATE_TAG, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_NUMBER
set -e

: "${DATE_TAG:=$(date +'%Y%m%d')}"

mkdir -p ./audit_logs

gh api /repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs \
  --jq '.jobs[] | select(.name | test("GKI|CLO")) | [.id, .name] | @tsv' \
  > /tmp/build_jobs.tsv

while IFS=$'\t' read -r JOB_ID JOB_NAME; do
  SAFE=$(echo "$JOB_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g' | sed 's/^_//')
  gh api /repos/${GITHUB_REPOSITORY}/actions/jobs/${JOB_ID}/logs \
    2>/dev/null \
    | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]*Z //' \
    > "./audit_logs/${SAFE}.log" \
    || echo "[WARN] could not fetch: $JOB_NAME" > "./audit_logs/${SAFE}.log"
done < /tmp/build_jobs.tsv

cat > ./audit_logs/00_run_info.txt << EOF
Run    : #${GITHUB_RUN_NUMBER}
Repo   : ${GITHUB_REPOSITORY}
SHA    : ${GITHUB_SHA}
Date   : $(date -u +'%Y-%m-%d %H:%M:%S UTC')
URL    : https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
EOF

LOG_ZIP="build-audit-logs-${DATE_TAG}.zip"
zip -r9 "$LOG_ZIP" audit_logs/
LOG_SIZE_MB=$(echo "scale=2; $(stat -c%s "$LOG_ZIP") / 1024 / 1024" | bc | sed 's/^\./0./')

echo "LOG_AUDIT_ZIP=$LOG_ZIP"         >> "${GITHUB_ENV:-/dev/null}"
echo "LOG_AUDIT_SIZE_MB=$LOG_SIZE_MB" >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Audit log: $LOG_ZIP ($LOG_SIZE_MB MB)"
