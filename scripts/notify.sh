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

# ─── Success ──────────────────────────────────────────────────────────────────
if [ "$MODE" = "success" ]; then
  : "${RUN_URL:?}" "${RUN_NUMBER:?}" "${START_TIME:?}"
  : "${RELEASE_URL:-}" "${BUILD_TYPE:-stable}"

  SHORT_SHA="${SHA:0:9}"
  DURATION=$(( $(date +%s) - START_TIME ))
  DATE_STR=$(date -u +'%Y-%m-%d')

  # Escape + in tag so curl form-encoding doesn't turn it into a space
  DISPLAY_TAG=$(printf '%s' "${RELEASE_TAG}" | sed 's/+/%2B/g')

  UNAME_STR="${KERNEL_UNAME:-${KERNEL_VERSION:-unknown}}"

  [ "$BUILD_TYPE" = "testing" ] && ICON="🧪" && LABEL="Testing Build" \
    || ICON="✅" && LABEL="Build Success"

  MSG="<b>${ICON} ${LABEL}</b>%0A%0A"
  MSG="${MSG}<b>🔄</b> Run #${RUN_NUMBER} · sapphire%0A"
  MSG="${MSG}<b>🏷️</b> <code>${DISPLAY_TAG}</code>%0A"
  MSG="${MSG}<b>🐧</b> <code>${UNAME_STR}</code>%0A"
  MSG="${MSG}<b>⏱️</b> $((DURATION/60))m $((DURATION%60))s%0A"
  MSG="${MSG}<b>🔨</b> <a href='https://github.com/${GITHUB_REPOSITORY}/commit/${SHA}'>${SHORT_SHA}</a>%0A%0A"

  MSG="${MSG}<b>📦 KSU / SUSFS</b>%0A"
  MSG="${MSG}• Wild-KSU: <code>${WILD_TAG}</code>%0A"
  MSG="${MSG}• SukiSU-Ultra: <code>${SUKI_TAG}</code>%0A"
  MSG="${MSG}• SUSFS module: <code>${SUSFS_VERSION}</code>%0A%0A"

  MSG="${MSG}<b>📋</b> Run #${RUN_NUMBER} · ${DATE_STR} · ${BUILD_TYPE}%0A"
  MSG="${MSG}<b>📦</b> ${ZIP_MODE:-per-variant} · GKI × Wild/SukiSU/NoKSU%0A"
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

# ─── Failure ─────────────────────────────────────────────────────────────────
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

# ─── Source check ─────────────────────────────────────────────────────────────
elif [ "$MODE" = "check" ]; then
  : "${RUN_URL:?}"

  # These are set by check-sources.sh via GITHUB_ENV
  MSG="<b>🔍 Source Update Check</b>%0A%0A"
  MSG="${MSG}<b>Wild-KSU:</b> <code>${CHECK_WILD_TAG:-?}</code>%0A"
  MSG="${MSG}<b>SukiSU-Ultra:</b> <code>${CHECK_SUKI_TAG:-?}</code>%0A"
  MSG="${MSG}<b>SUSFS:</b> <code>${CHECK_SUSFS_COMMIT:-?}</code> (${CHECK_SUSFS_DATE:-?})%0A"
  MSG="${MSG}<b>GKI 5.15 latest:</b> <code>${CHECK_GKI_SUB:-?}</code>%0A%0A"
  MSG="${MSG}<b>🔗</b> <a href='${RUN_URL}'>Run details</a>"
  _tg_msg "$MSG"

else
  echo "[ERROR] Unknown mode: $MODE"
  exit 1
fi
