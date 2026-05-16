#!/usr/bin/env bash
# patch helper — source this before calling apply_patch()
apply_patch() {
  local SRC="$1" NAME="$2" STRICT="${3:-0}"
  local TMP="/tmp/p_${NAME//[^a-zA-Z0-9]/_}"

  if [[ "$SRC" == http* ]]; then
    curl -LSs --fail "$SRC" -o "$TMP" 2>/dev/null || { echo "[SKIP] $NAME — download failed"; return 0; }
  else
    [ -f "$SRC" ] || { echo "[SKIP] $NAME — not found: $SRC"; return 0; }
    cp "$SRC" "$TMP"
  fi

  local missing=""
  while IFS= read -r line; do
    [[ "$line" =~ ^---\ a/(.+)$ ]] || continue
    local t="${BASH_REMATCH[1]}"
    [[ "$t" == "/dev/null" ]] && continue
    [ -f "$t" ] || missing="$missing $t"
  done < "$TMP"
  [ -n "$missing" ] && { echo "[SKIP] $NAME — missing:$missing"; rm -f "$TMP"; return 0; }

  patch -p1 --dry-run --forward --quiet < "$TMP" 2>/dev/null || { echo "[SKIP] $NAME — already applied"; rm -f "$TMP"; return 0; }

  if patch -p1 --forward < "$TMP"; then
    echo "[OK]  $NAME"
  else
    [ "$STRICT" = "1" ] && { echo "[FAIL] $NAME"; rm -f "$TMP"; return 1; }
    echo "[WARN] $NAME — skipped"
  fi
  rm -f "$TMP"
}
