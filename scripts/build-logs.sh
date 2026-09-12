#!/usr/bin/env bash
# build-logs.sh — collect per-job build logs into a zip, with a quick-look
# excerpt around the first error line for any job that failed.
# env: GH_TOKEN, BUILD_TYPE, KERNEL_VERSION, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_NUMBER
set -e
set -o pipefail

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

# Fetch one job's log with retry/backoff. GitHub's log storage can lag a few
# seconds behind job completion, so a single failed attempt is not proof the
# log doesn't exist yet — but repeated failure after backoff is a real error
# and must not be papered over with a placeholder file.
# Returns 0 on success (log written to $2), 1 if all attempts failed (raw
# stderr from the last attempt written to $3 for audit purposes).
_fetch_job_log() {
  local job_id="$1" out="$2" errout="$3"
  local attempt raw_err
  for attempt in 1 2 3 4 5; do
    raw_err=$(mktemp)
    if gh api "/repos/${GITHUB_REPOSITORY}/actions/jobs/${job_id}/logs" 2>"$raw_err" | _clean_log > "$out"; then
      rm -f "$raw_err"
      return 0
    fi
    if [ "$attempt" -lt 5 ]; then
      sleep $(( attempt * 5 ))
    fi
  done
  cp "$raw_err" "$errout"
  rm -f "$raw_err"
  return 1
}

FETCH_FAILED=0

while IFS=$'\t' read -r JOB_ID JOB_NAME CONCLUSION; do
  # Extract variant part after " / " — e.g. "🔨 GKI-Wild / GKI-Wild" → "GKI-Wild"
  SAFE=$(echo "$JOB_NAME" | sed 's|.* / ||' | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g; s/^_//; s/_$//')

  if ! _fetch_job_log "$JOB_ID" "./logs/${SAFE}.log" "./logs/${SAFE}.fetch-error.log"; then
    echo "[ERROR] could not fetch log for job: $JOB_NAME (id=$JOB_ID) after 5 attempts — see ${SAFE}.fetch-error.log" >&2
    FETCH_FAILED=1
    continue
  fi

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

if [ "$FETCH_FAILED" -ne 0 ]; then
  echo "[FAIL] One or more job logs could not be fetched after retries." >&2
  echo "[FAIL] Zip was still written to $LOG_ZIP for inspection, but this run should NOT be treated as a complete audit trail." >&2
  exit 1
fi

echo "[OK] Build log: $LOG_ZIP ($LOG_SIZE_MB MB)"

