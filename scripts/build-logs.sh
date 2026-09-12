#!/usr/bin/env bash
# build-logs.sh — assemble per-variant build logs from artifacts uploaded
# by each build-kernel.yml job, then zip for release.
#
# No GitHub API log-fetch: each variant uploads its own raw-log-<variant>
# artifact during the build job (if: always()), so logs are always available
# regardless of API endpoint reliability.
#
# env: GH_TOKEN, BUILD_TYPE, GITHUB_REPOSITORY, GITHUB_RUN_ID,
#      GITHUB_RUN_NUMBER, GITHUB_SHA
set -e
set -o pipefail

: "${BUILD_TYPE:-stable}"

mkdir -p ./logs

# Strip ANSI escape codes and GitHub Actions group markers
_clean_log() {
  sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b(B//g' \
  | sed '/^##\[group\]/d; /^##\[endgroup\]/d'
}

# Error excerpt — pull context around first known-bad pattern
_extract_excerpt() {
  local log="$1" out="$2"
  local hit
  hit=$(grep -n -m1 -E 'error:|FAILED|recipe for target .* failed|\*\*\* \[' "$log" | cut -d: -f1 || true)
  if [ -n "$hit" ]; then
    local start=$(( hit > 60 ? hit - 60 : 1 ))
    local end=$(( hit + 40 ))
    { echo "# excerpt: lines ${start}-${end} around first error match (line ${hit})";
      sed -n "${start},${end}p" "$log"; } > "$out"
  else
    { echo "# no known error pattern matched — tail of log follows";
      tail -n 150 "$log"; } > "$out"
  fi
}

MISSING=0

# Each build job uploaded: raw-log-<variant_name>/apply-patches.log
#                                                  build.log
#                                                  verify.log
# download-artifact placed them at ./artifacts/raw-log-*/
for log_dir in ./artifacts/raw-log-*/; do
  [ -d "$log_dir" ] || continue
  variant=$(basename "$log_dir" | sed 's/^raw-log-//')
  outfile="./logs/${variant}.log"

  # Combine step logs into one file with section headers
  {
    for step_log in \
        "$log_dir/apply-patches.log" \
        "$log_dir/build.log" \
        "$log_dir/verify.log"; do
      [ -f "$step_log" ] || continue
      step=$(basename "$step_log" .log)
      printf '=%.0s' {1..60}; echo
      echo "## ${step}"
      printf '=%.0s' {1..60}; echo
      _clean_log < "$step_log"
      echo
    done
  } > "$outfile"

  # Error excerpt (only written when a known-bad pattern is found)
  _extract_excerpt "$outfile" "./logs/${variant}-excerpt.log"
done

# Fail loudly if no log artifacts were found at all
ACTUAL=$(ls -d ./artifacts/raw-log-*/ 2>/dev/null | wc -l)
if [ "$ACTUAL" -eq 0 ]; then
  echo "[FAIL] No raw-log-* artifacts found." \
       "Did build-kernel.yml upload them?" >&2
  exit 1
fi

# Cross-check against how many GKI/CLO jobs actually ran in this run.
# This API call (listing jobs) is reliable — only the per-job /logs
# endpoint was unreliable; that endpoint is no longer used.
EXPECTED=$(gh api "/repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs" \
  --jq '[.jobs[] | select(.name | test("GKI|CLO"))] | length' 2>/dev/null || echo 0)

if [ "$EXPECTED" -gt 0 ] && [ "$ACTUAL" -lt "$EXPECTED" ]; then
  echo "[FAIL] Expected ${EXPECTED} log artifact(s), found ${ACTUAL}." \
       "One or more build jobs may have failed to upload their log." >&2
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

