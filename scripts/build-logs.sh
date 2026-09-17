#!/usr/bin/env bash
# build-logs.sh — download the full run log archive (same as GitHub's
# "Download log archive" button) and repack into clean, human-readable
# per-variant logs, no timestamps, no truncation.
# env: GH_TOKEN, BUILD_TYPE, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_NUMBER, GITHUB_SHA
set -e

: "${BUILD_TYPE:-stable}"

WORKDIR=$(mktemp -d)
RUN_ZIP="$WORKDIR/run-logs.zip"

_clean_log() {
  sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]*Z //' \
  | sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b(B//g' \
  | sed '/^##\[group\]/d; /^##\[endgroup\]/d'
}

echo "[..] Fetching full run log archive..."
FETCHED=0
for attempt in 1 2 3 4 5 6; do
  if gh api "/repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/logs" > "$RUN_ZIP" 2>"$WORKDIR/err.log"; then
    if [ -s "$RUN_ZIP" ] && unzip -tq "$RUN_ZIP" >/dev/null 2>&1; then
      FETCHED=1
      break
    fi
  fi
  echo "[..] attempt $attempt failed ($(cat "$WORKDIR/err.log" 2>/dev/null | head -1)), retrying in 15s..."
  sleep 15
done

if [ "$FETCHED" -ne 1 ]; then
  echo "[FAIL] Could not fetch run log archive after 6 attempts." >&2
  exit 1
fi

mkdir -p "$WORKDIR/extracted"
unzip -q "$RUN_ZIP" -d "$WORKDIR/extracted"

mkdir -p ./audit_logs

# Each top-level *.txt in the archive (not inside a subdirectory) is one
# job's full log, already containing every step in run order.
find "$WORKDIR/extracted" -maxdepth 1 -type f | while read -r job_file; do
  case "$job_file" in
    *.txt) ;;
    *) continue ;;
  esac
  case "$job_file" in
    *GKI*|*CLO*) ;;
    *) continue ;;
  esac
  job_name=$(basename "$job_file" .txt | sed 's/^[0-9]*_//')
  # keep only the part before " _ " (job name before the repeated "/ step" suffix), strip emoji/non-ascii
  safe=$(echo "$job_name" | sed 's/ _ .*//' | tr -cd '[:alnum:]._-')
  [ -z "$safe" ] && safe="job_$(basename "$job_file" .txt | tr -cd '0-9')"
  cat "$job_file" \
    | _clean_log \
    > "./audit_logs/${safe}.log"
done

if [ -z "$(ls -A ./audit_logs 2>/dev/null)" ]; then
  echo "[FAIL] No matching job logs found in run archive." >&2
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
echo "[OK] Build log: $LOG_ZIP (${LOG_SIZE_MB} MB)"

rm -rf "$WORKDIR"
