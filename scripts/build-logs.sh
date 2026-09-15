#!/usr/bin/env bash
# build-logs.sh — assemble per-variant build logs from uploaded artifacts,
# then enrich each with the full job log fetched via GitHub API.
# env: GH_TOKEN, BUILD_TYPE, GITHUB_REPOSITORY, GITHUB_RUN_ID,
#      GITHUB_RUN_NUMBER, GITHUB_SHA
set -e
set -o pipefail

: "${BUILD_TYPE:-stable}"

mkdir -p ./logs

# Strip ANSI escape codes, GitHub Actions group markers, and ISO timestamp prefix
_clean_log() {
  sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]*Z //' \
  | sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b(B//g' \
  | sed '/^##\[group\]/d; /^##\[endgroup\]/d'
}

# Build job ID → name map from API
gh api /repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs \
  --jq '.jobs[] | select(.name | test("GKI|CLO")) | [.id, .name] | @tsv' \
  > /tmp/build_jobs.tsv

# Per-variant: combine tee'd step logs (fast, always present) +
# full API log (complete, may be slower or unavailable — graceful fallback)
for log_dir in ./artifacts/raw-log-*/; do
  [ -d "$log_dir" ] || continue
  variant=$(basename "$log_dir" | sed 's/^raw-log-//')
  outfile="./logs/${variant}.log"

  {
    for step_log in \
        "$log_dir/apply-patches.log" \
        "$log_dir/build.log" \
        "$log_dir/verify.log"; do
      [ -f "$step_log" ] || continue
      step=$(basename "$step_log" .log)
      printf '=%.0s' $(seq 1 60); echo
      echo "## ${step}"
      printf '=%.0s' $(seq 1 60); echo
      _clean_log < "$step_log"
      echo
    done
  } > "$outfile"
done

# Enrich each variant log with full API-fetched job log (appended as extra section)
while IFS=$'\t' read -r JOB_ID JOB_NAME; do
  SAFE=$(echo "$JOB_NAME" | sed 's|.* / ||' | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g; s/^_//; s/_$//')
  outfile="./logs/${SAFE}.log"
  {
    printf '=%.0s' $(seq 1 60); echo
    echo "## full-api-log"
    printf '=%.0s' $(seq 1 60); echo
    gh api /repos/${GITHUB_REPOSITORY}/actions/jobs/${JOB_ID}/logs \
      2>/dev/null \
      | _clean_log \
      || echo "[WARN] API log unavailable for: $JOB_NAME"
  } >> "$outfile"
done < /tmp/build_jobs.tsv

ACTUAL=$(ls -d ./artifacts/raw-log-*/ 2>/dev/null | wc -l)
if [ "$ACTUAL" -eq 0 ]; then
  echo "[FAIL] No raw-log-* artifacts found." >&2
  exit 1
fi

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
