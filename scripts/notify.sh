#!/usr/bin/env bash
# notify.sh — Telegram notification dispatcher
# Usage: notify.sh <success|failure|check>
# Required env: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
# Optional env: TELEGRAM_TOPIC_ID (thread/topic ID for group topics)

set -euo pipefail

MODE="${1:?usage: notify.sh <success|failure|check>}"

: "${TELEGRAM_BOT_TOKEN:?}"
: "${TELEGRAM_CHAT_ID:?}"

_tg_msg() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    ${TELEGRAM_TOPIC_ID:+-d message_thread_id="$TELEGRAM_TOPIC_ID"} \
    -d text="$1" \
    -d parse_mode="HTML" \
    -d disable_web_page_preview=true \
    > /dev/null
}

_tg_doc() {
  local FILE="$1" CAPTION="$2"
  [ -f "$FILE" ] || return 0
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
    -F chat_id="$TELEGRAM_CHAT_ID" \
    ${TELEGRAM_TOPIC_ID:+-F message_thread_id="$TELEGRAM_TOPIC_ID"} \
    -F document=@"$FILE" \
    -F caption="$CAPTION" \
    > /dev/null
}

# ---------------------------------------------------------------------------
# success — after the release job published (or after a skip_release build)
# ---------------------------------------------------------------------------
if [ "$MODE" = "success" ]; then
  : "${RUN_URL:?}" "${RUN_NUMBER:?}" "${START_TIME:?}" "${SHA:?}"

  SHORT_SHA="${SHA:0:8}"
  COMMIT_MSG=$(git log -1 --format=%s 2>/dev/null || echo "")
  DURATION=$(( $(date +%s) - START_TIME ))
  DATE_STR=$(date -u +'%Y-%m-%d')

  BUILD_LABEL="Stable"
  [ "${BUILD_TYPE:-stable}" = "testing" ] && BUILD_LABEL="Testing"

  # URL-encode + in tag (form-encoding turns it into space otherwise)
  DISPLAY_TAG=$(printf '%s' "${RELEASE_TAG:-}" | sed 's/+/%2B/g')
  DISPLAY_SUSFS=$(printf '%s' "${SUSFS_MODULE_VERSION:-${SUSFS_VERSION:-}}" | sed 's/+/%2B/g')

  RELEASE_LINK="${RELEASE_URL:-https://github.com/${GITHUB_REPOSITORY}/releases}"

  MSG="<b>[${BUILD_LABEL}] Seiran Kernel</b>%0A%0A"
  MSG="${MSG}Run: #${RUN_NUMBER}%0A"
  MSG="${MSG}Branch: ${GITHUB_REF_NAME:-unknown}%0A"
  MSG="${MSG}Actor: ${GITHUB_ACTOR:-yurika-sudo}%0A"
  MSG="${MSG}Commit: <a href='https://github.com/${GITHUB_REPOSITORY}/commit/${SHA}'>${SHORT_SHA}</a>%0A"
  [ -n "$COMMIT_MSG" ] && MSG="${MSG}Message: ${COMMIT_MSG}%0A"
  MSG="${MSG}%0A"
  MSG="${MSG}Duration: $((DURATION/60))m $((DURATION%60))s%0A"
  MSG="${MSG}Date: ${DATE_STR}%0A"
  MSG="${MSG}Tag: <code>${DISPLAY_TAG}</code>%0A"
  MSG="${MSG}%0A"
  MSG="${MSG}KSU-Next: <code>${KSUN_TAG:-unknown}</code> · <code>${KSUN_VERSION:-?}</code>%0A"
  MSG="${MSG}SUSFS: <code>${SUSFS_VERSION:-?}</code> (module <code>${DISPLAY_SUSFS}</code>)%0A"
  MSG="${MSG}DroidSpaces: <code>${DROIDSPACES_VERSION:-?}</code>%0A"
  MSG="${MSG}%0A"
  MSG="${MSG}<a href='${RELEASE_LINK}'>Release</a>%0A"
  MSG="${MSG}<a href='${RUN_URL}'>Logs</a>"

  _tg_msg "$MSG"

  # Attach the release ZIPs
  for ZIP in ./release_zips/*.zip; do
    [ -f "$ZIP" ] || continue
    SIZE_MB=$(echo "scale=1; $(stat -c%s "$ZIP") / 1048576" | bc | sed 's/^\./0./')
    _tg_doc "$ZIP" "$(basename "$ZIP") — ${SIZE_MB} MB"
  done

# ---------------------------------------------------------------------------
# failure — the build job did not finish (failed, cancelled or timed out)
# ---------------------------------------------------------------------------
elif [ "$MODE" = "failure" ]; then
  : "${RUN_URL:?}" "${RUN_NUMBER:?}"

  BUILD_LABEL="Stable"
  [ "${BUILD_TYPE:-stable}" = "testing" ] && BUILD_LABEL="Testing"

  case "${BUILD_STATUS:-failure}" in
    cancelled) WHAT="Build cancelled" ;;
    failure)   WHAT="Build failed" ;;
    *)         WHAT="Build ${BUILD_STATUS:-failed}" ;;
  esac

  MSG="<b>[${BUILD_LABEL}] ${WHAT} — Run #${RUN_NUMBER}</b>%0A%0A"
  MSG="${MSG}<a href='${RUN_URL}'>Logs</a>"

  _tg_msg "$MSG"

# ---------------------------------------------------------------------------
# check — called from check-updates.yml notify job
# ---------------------------------------------------------------------------
elif [ "$MODE" = "check" ]; then
  : "${RUN_URL:?}"

  HEAD="<b>[check-updates] "
  if [ "${HAS_UPDATE:-false}" = "true" ]; then
    HEAD="${HEAD}Upstream update detected</b>%0A%0A"
    [ -n "${UPDATE_DETAIL:-}" ] && HEAD="${HEAD}${UPDATE_DETAIL}%0A%0A"
  else
    HEAD="${HEAD}No upstream changes</b>%0A%0A"
  fi

  MSG="${HEAD}"
  MSG="${MSG}KSU-Next: <code>${CHECK_KSUN_TAG:-?}</code>%0A"
  MSG="${MSG}SUSFS: <code>${CHECK_SUSFS_VER:-?}</code> · module <code>${CHECK_SUSFS_TAG:-?}</code>%0A"
  MSG="${MSG}DroidSpaces: <code>${CHECK_DROIDSPACES:-?}</code>%0A"
  MSG="${MSG}GKI: <code>${CHECK_GKI_SUB:-?}</code>%0A"

  if [ -n "${HELD_BACK:-}" ]; then
    MSG="${MSG}%0AHeld back (verify build did not pass):%0A"
    while IFS= read -r line; do
      [ -n "$line" ] && MSG="${MSG}  ${line}%0A"
    done <<< "$HELD_BACK"
  fi

  # A lookup that could not reach upstream is not an update — say so, but keep
  # the rest of the report, since the pins were left at last known-good.
  if [ "${CHECK_FAILED:-false}" = "true" ]; then
    MSG="${MSG}%0A⚠️ Could not fetch (kept last known-good pin): ${CHECK_FAILED_DETAIL:-see logs}%0A"
  fi

  MSG="${MSG}%0A<a href='${RUN_URL}'>Logs</a>"
  _tg_msg "$MSG"

else
  echo "notify.sh: unknown mode '$MODE'" >&2
  exit 1
fi
