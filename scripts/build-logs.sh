#!/usr/bin/env bash
# build-logs.sh — collect per-variant raw build logs into a zip
# Reads build-<variant>.log files from downloaded artifact dirs under ./artifacts/
# No GitHub API calls — no race condition, no 0-byte risk.
# env: BUILD_TYPE, GITHUB_REPOSITORY, GITHUB_RUN_NUMBER, GITHUB_SHA, GITHUB_RUN_ID
set -e

: "${BUILD_TYPE:-stable}"

mkdir -p ./audit_logs

# Raw build log per variant (uploaded by build-kernel.yml "Collect build log" step)
find ./artifacts -name "build-*.log" | sort | while read -r f; do
  VARIANT=$(basename "$f")
  cp "$f" "./audit_logs/${VARIANT}"
done

# Kernel uname per variant
find ./artifacts -name "kernel_uname.txt" | sort | while read -r f; do
  VARIANT=$(basename "$(dirname "$f")")
  cp "$f" "./audit_logs/${VARIANT}-kernel_uname.txt" 2>/dev/null || true
done

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
