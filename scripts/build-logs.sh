#!/usr/bin/env bash
# build-logs.sh — fetch full per-job logs via GitHub API (complete, includes
# runner banner); falls back to tee'd step artifacts if API unavailable.
# env: GH_TOKEN, BUILD_TYPE, GITHUB_REPOSITORY, GITHUB_RUN_ID,
#      GITHUB_RUN_NUMBER, GITHUB_SHA
set -e
set -o pipefail

: "${BUILD_TYPE:-stable}"

mkdir -p ./logs

_clean_log() {
  sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]*Z //' \
  | sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b(B//g' \
  | sed '/^##\[group\]/d; /^##\[endgroup\]/d'
}

gh api /repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs \
  --jq '.jobs[] | select(.name | test("GKI|CLO")) | [.id, .name] | @tsv' \
  > /tmp/build_jobs.tsv

ACTUAL=0
while IFS=$'\t' read -r JOB_ID JOB_NAME; do
  SAFE=$(echo "$JOB_NAME" | sed 's|.* / ||' | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g; s/^_//; s/_$//')
  outfile="./logs/${SAFE}.log"

  gh api /repos/${GITHUB_REPOSITORY}/actions/jobs/${JOB_ID}/logs \
      2>"/tmp/gh_err_${SAFE}.log" | _clean_log > "$outfile"
  if [ -s "$outfile" ]; then
    ACTUAL=$((ACTUAL + 1))
  else
    # Fallback: artifact step logs
    log_dir="./artifacts/raw-log-${SAFE}"
    if [ -d "$log_dir" ]; then
      echo "[WARN] API unavailable for $JOB_NAME — using artifact fallback" > "$outfile"
      for step_log in "$log_dir/apply-patches.log" "$log_dir/build.log" "$log_dir/verify.log"; do
        [ -f "$step_log" ] || continue
        step=$(basename "$step_log" .log)
        printf '=%.0s' $(seq 1 60); echo
        echo "## ${step}"
        printf '=%.0s' $(seq 1 60); echo
        _clean_log < "$step_log"
        echo
      done >> "$outfile"
      ACTUAL=$((ACTUAL + 1))
    else
      echo "[WARN] No log available for: $JOB_NAME" > "$outfile"
    fi
  fi
done < /tmp/build_jobs.tsv

[ "$ACTUAL" -gt 0 ] || { echo "[FAIL] No logs collected." >&2; exit 1; }

cat > ./logs/00_run_info.txt << RUNINFO
Run    : #${GITHUB_RUN_NUMBER}
Repo   : ${GITHUB_REPOSITORY}
SHA    : ${GITHUB_SHA}
Date   : $(date -u +'%Y-%m-%d %H:%M:%S UTC')
Type   : ${BUILD_TYPE}
URL    : https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
RUNINFO

LOG_DATE=$(date -u +'%Y-%m-%d')
LOG_ZIP="build-log-run${GITHUB_RUN_NUMBER}-${LOG_DATE}-${BUILD_TYPE}.zip"
zip -r9 "$LOG_ZIP" logs/
LOG_SIZE_MB=$(echo "scale=2; $(stat -c%s "$LOG_ZIP") / 1024 / 1024" | bc | sed 's/^\./0./')

echo "LOG_ZIP=$LOG_ZIP"         >> "${GITHUB_ENV:-/dev/null}"
echo "LOG_SIZE_MB=$LOG_SIZE_MB" >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Build log: $LOG_ZIP (${LOG_SIZE_MB} MB) — ${ACTUAL} variant(s)"
