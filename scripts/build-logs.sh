#!/usr/bin/env bash
# build-logs.sh — collect per-job build logs into a zip, with a quick-look
# excerpt around the first error line for any job that failed.
# env: GH_TOKEN, BUILD_TYPE, KERNEL_VERSION, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_NUMBER
set -e

: "${BUILD_TYPE:-stable}"

mkdir -p ./logs

gh api /repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs \
  --jq '.jobs[] | select(.name | test("GKI|CLO")) | [.id, .name, .conclusion] | @tsv' \
  > /tmp/build_jobs.tsv

# Strip ISO timestamp prefix and ANSI escape codes only — no filtering, no headers
_clean_log() {
  sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]*Z //' \
  | sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b(B//g' \
  | sed '/^##\[group\]/d; /^##\[endgroup\]/d'
}

# Pull a window of lines around the first build-failure signature in a log,
# so a failed job can be debugged without scrolling the full file.
_extract_excerpt() {
  local log="$1" out="$2"
  local hit
  hit=$(grep -n -m1 -E 'error:|FAILED|recipe for target .* failed|\*\*\* \[' "$log" | cut -d: -f1 || true)
  if [ -n "$hit" ]; then
    local start=$(( hit > 60 ? hit - 60 : 1 ))
    local end=$(( hit + 40 ))
    { echo "# excerpt: lines ${start}-${end} around first error match (line ${hit})"; \
      sed -n "${start},${end}p" "$log"; } > "$out"
  else
    { echo "# no known error pattern matched — tail of log follows"; \
      tail -n 150 "$log"; } > "$out"
  fi
}

while IFS=$'\t' read -r JOB_ID JOB_NAME CONCLUSION; do
  # Extract variant part after " / " — e.g. "🔨 GKI-Wild / GKI-Wild" → "GKI-Wild"
  SAFE=$(echo "$JOB_NAME" | sed 's|.* / ||' | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g; s/^_//; s/_$//')
  gh api /repos/${GITHUB_REPOSITORY}/actions/jobs/${JOB_ID}/logs \
    2>/dev/null \
    | _clean_log \
    > "./logs/${SAFE}.log" \
    || echo "[WARN] could not fetch: $JOB_NAME" > "./logs/${SAFE}.log"

  if [ "$CONCLUSION" = "failure" ]; then
    _extract_excerpt "./logs/${SAFE}.log" "./logs/${SAFE}-excerpt.log"
  fi
done < /tmp/build_jobs.tsv

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

echo "LOG_ZIP=$LOG_ZIP"           >> "${GITHUB_ENV:-/dev/null}"
echo "LOG_SIZE_MB=$LOG_SIZE_MB"   >> "${GITHUB_ENV:-/dev/null}"
echo "[OK] Build log: $LOG_ZIP ($LOG_SIZE_MB MB)"
