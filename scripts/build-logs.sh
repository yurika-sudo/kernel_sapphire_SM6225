#!/usr/bin/env bash
# build-logs.sh — collect per-variant build logs from downloaded artifacts
# env: BUILD_TYPE, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_NUMBER, GITHUB_SHA
set -e

: "${BUILD_TYPE:-stable}"

mkdir -p ./audit_logs

_clean_log() {
  sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]*Z //' \
  | sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b(B//g' \
  | sed '/^##\[group\]/d; /^##\[endgroup\]/d'
}

ACTUAL=0
for log_dir in ./artifacts/raw-log-*/; do
  [ -d "$log_dir" ] || continue
  variant=$(basename "$log_dir" | sed 's/^raw-log-//')
  outfile="./audit_logs/${variant}.log"
  cat "$log_dir"/*.log 2>/dev/null \
    | _clean_log \
    > "$outfile" \
    || echo "[WARN] no log files found in $log_dir" > "$outfile"
  ACTUAL=$((ACTUAL + 1))
done

if [ "$ACTUAL" -eq 0 ]; then
  echo "[FAIL] No raw-log-* artifacts found." >&2
  exit 1
fi

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
echo "[OK] Build log: $LOG_ZIP (${LOG_SIZE_MB} MB) — ${ACTUAL} variant(s)"
