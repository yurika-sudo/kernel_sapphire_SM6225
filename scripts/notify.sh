#!/usr/bin/env bash
# notify.sh — telegram notifications dispatcher
# Usage: notify.sh <success|failure|check>
# env: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, + mode-specific vars

MODE="${1:?usage: notify.sh <success|failure|check>}"

: "${TELEGRAM_BOT_TOKEN:?}"
: "${TELEGRAM_CHAT_ID:?}"

_tg_msg() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="$1" \
    -d parse_mode="HTML" \
    -d disable_web_page_preview=true
}

_tg_doc() {
  local FILE="$1" CAPTION="$2"
  [ -f "$FILE" ] || return 0
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
    -F chat_id="$TELEGRAM_CHAT_ID" \
    -F document=@"$FILE" \
    -F caption="$CAPTION"
}

if [ "$MODE" = "success" ]; then
  : "${RUN_URL:?}" "${RUN_NUMBER:?}" "${START_TIME:?}"
  : "${RELEASE_URL:-}" "${BUILD_TYPE:-stable}"

  SHORT_SHA="${SHA:0:9}"
  DURATION=$(( $(date +%s) - START_TIME ))
  DATE_STR=$(date -u +'%Y-%m-%d')

  # Escape + in tag so curl form-encoding doesn't turn it into a space
  DISPLAY_TAG=$(printf '%s' "${RELEASE_TAG}" | sed 's/+/%2B/g')
  DISPLAY_SUSFS=$(printf '%s' "${SUSFS_VERSION}" | sed 's/+/%2B/g')

  UNAME_STR="${KERNEL_UNAME:-${KERNEL_VERSION:-unknown}}"

  [ "$BUILD_TYPE" = "testing" ] && { ICON="🧪"; LABEL="Testing Build"; } \
    || { ICON="✅"; LABEL="Build Success"; }

  MSG="<b>${ICON} ${LABEL}</b>%0A%0A"
  MSG="${MSG}<b>🔄</b> Run #${RUN_NUMBER} · sapphire%0A"
  MSG="${MSG}<b>🏷️</b> <code>${DISPLAY_TAG}</code>%0A"
  MSG="${MSG}<b>🐧</b> <code>${UNAME_STR}</code>%0A"
  MSG="${MSG}<b>⏱️</b> $((DURATION/60))m $((DURATION%60))s%0A"
  MSG="${MSG}<b>🔨</b> <a href='https://github.com/${GITHUB_REPOSITORY}/commit/${SHA}'>${SHORT_SHA}</a>%0A%0A"

  MSG="${MSG}<b>📦 KSU / SUSFS</b>%0A"
  MSG="${MSG}• KSU-Next: <code>${KSUN_TAG}</code>%0A"
  MSG="${MSG}• SukiSU-Ultra: <code>${SUKI_TAG}</code>%0A"
  MSG="${MSG}• SUSFS module: <code>${DISPLAY_SUSFS}</code>%0A%0A"

  MSG="${MSG}<b>📋</b> Run #${RUN_NUMBER} · ${DATE_STR} · ${BUILD_TYPE}%0A"
  MSG="${MSG}<b>📦</b> ${ZIP_MODE:-per-variant} · GKI/CLO × Next/SukiSU/NoKSU%0A"
  MSG="${MSG}<b>🔗</b> <a href='${RELEASE_URL}'>Release</a> · <a href='${RUN_URL}'>Logs</a>"
  _tg_msg "$MSG"

  # Send ZIPs
  for ZIP in ./release_zips/*.zip; do
    [ -f "$ZIP" ] || continue
    SIZE_MB=$(echo "scale=2; $(stat -c%s "$ZIP") / 1024 / 1024" | bc | sed 's/^\./0./')
    _tg_doc "$ZIP" "📦 $(basename "$ZIP") — ${SIZE_MB} MB"
  done

  # Send audit log
  if [ -n "$LOG_AUDIT_ZIP" ] && [ -f "$LOG_AUDIT_ZIP" ]; then
    if (( $(echo "$LOG_AUDIT_SIZE_MB < 45" | bc -l) )); then
      _tg_doc "$LOG_AUDIT_ZIP" "📋 $(basename "$LOG_AUDIT_ZIP") — ${LOG_AUDIT_SIZE_MB} MB"
    else
      _tg_msg "📋 Log too large (${LOG_AUDIT_SIZE_MB} MB) — grab from <a href='${RELEASE_URL}'>release</a>."
    fi
  fi

elif [ "$MODE" = "failure" ]; then
  : "${RUN_URL:?}" "${RUN_NUMBER:?}"
  STATUS="${BUILD_STATUS:-failed}"
  [ "$STATUS" = "cancelled" ] && ICON="⚠️" && LABEL="Cancelled" \
    || ICON="❌" && LABEL="Build Failed"

  MSG="<b>${ICON} ${LABEL}</b>%0A%0A"
  MSG="${MSG}<b>🔄</b> Run #${RUN_NUMBER} · sapphire%0A"
  MSG="${MSG}<b>🕐</b> $(date -u +'%Y-%m-%d %H:%M UTC')%0A"
  MSG="${MSG}<b>🔗</b> <a href='${RUN_URL}'>Logs</a>"
  _tg_msg "$MSG"

elif [ "$MODE" = "check" ]; then
  : "${RUN_URL:?}"

  # Escape + so curl form-encoding doesn't turn it into a space
  DISPLAY_SUSFS_TAG=$(printf '%s' "${CHECK_SUSFS_TAG:-?}" | sed 's/+/%2B/g')

  # Status header
  if [ "${HAS_UPDATE:-false}" = "true" ]; then
    STATUS_LINE="<b>🆕 Updates available</b>"
  else
    STATUS_LINE="<b>✅ All sources up to date</b>"
  fi

  MSG="<b>🔍 Source Update Check</b>%0A%0A"
  MSG="${MSG}${STATUS_LINE}%0A%0A"
  MSG="${MSG}<b>GKI 5.15:</b>    <code>${CHECK_GKI_SUB:-?}</code>%0A"
  MSG="${MSG}<b>CLO 5.15:</b>    <code>${CHECK_CLO_SUB:-?}</code>%0A"
  MSG="${MSG}<b>KSU-Next:</b>    <code>${CHECK_KSUN_TAG:-?}</code>%0A"
  MSG="${MSG}<b>SukiSU-Ultra:</b> <code>${CHECK_SUKI_TAG:-?}</code>%0A"
  MSG="${MSG}<b>SUSFS:</b>       <code>${DISPLAY_SUSFS_TAG}</code>%0A"

  # Show what changed
  if [ "${HAS_UPDATE:-false}" = "true" ] && [ -n "${UPDATE_DETAIL:-}" ]; then
    MSG="${MSG}%0A<b>📋 Changes:</b>%0A"
    while IFS= read -r LINE; do
      [ -z "$LINE" ] && continue
      LINE_ESC=$(printf '%s' "$LINE" | sed 's/+/%2B/g')
      MSG="${MSG}▸ ${LINE_ESC}%0A"
    done <<< "$UPDATE_DETAIL"
    MSG="${MSG}%0ATrigger a stable build from Actions when ready."
  fi

  MSG="${MSG}%0A%0A<b>🔗</b> <a href='${RUN_URL}'>Run details</a>"
  _tg_msg "$MSG"

elif [ "$MODE" = "variant-failure" ]; then
  : "${RUN_URL:?}" "${RUN_NUMBER:?}" "${VARIANT:?}"

  # Pick log file based on source type
  LOG_FILE="/tmp/build_${SOURCE_TYPE:-gki}.log"

  # Extract last 20 unique error lines, strip long path prefix
  ERRORS=""
  if [ -f "$LOG_FILE" ]; then
    ERRORS=$(grep -E " error:" "$LOG_FILE" \
      | sed 's|.*/kernel_src/||' \
      | awk '!seen[$0]++' \
      | tail -20 \
      | head -c 1800)
  fi

  [ "$BUILD_TYPE" = "testing" ] && TYPE_ICON="🧪" || TYPE_ICON="🔨"

  MSG="<b>❌ Build Failed — ${VARIANT}</b>%0A%0A"
  MSG="${MSG}<b>${TYPE_ICON}</b> ${BUILD_TYPE:-stable} · Run #${RUN_NUMBER}%0A"
  MSG="${MSG}<b>🕐</b> $(date -u +'%H:%M UTC')%0A"
  MSG="${MSG}<b>🔗</b> <a href='${RUN_URL}'>Logs</a>"

  if [ -n "$ERRORS" ]; then
    MSG="${MSG}%0A%0A<b>🔍 Errors:</b>%0A<pre>${ERRORS}</pre>"
  fi

  _tg_msg "$MSG"

else
  echo "[ERROR] Unknown mode: $MODE"
  exit 1
fi
