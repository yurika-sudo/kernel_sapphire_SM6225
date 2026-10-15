#!/usr/bin/env bash
# patch helper — source this before calling apply_patch()
#
# apply_patch <src> <name> [strict]
#   src    local path or http(s) URL
#   name   label used in logs and for the temp file
#   strict "1" turns every failure (download, missing target file, rejected
#          hunk) into a non-zero return so callers running with `set -e` abort.
#          Use it where a missing patch breaks correctness or safety, not for
#          best-effort tuning patches.
apply_patch() {
  local SRC="$1" NAME="$2" STRICT="${3:-0}"
  local TMP="/tmp/p_${NAME//[^a-zA-Z0-9]/_}"
  local missing="" t line

  _skip() {   # lenient failure: log and continue; fatal when strict
    if [ "$STRICT" = "1" ]; then
      echo "[FAIL] $NAME — $1 (strict)" >&2
      rm -f "$TMP"
      return 1
    fi
    echo "[SKIP] $NAME — $1"
    rm -f "$TMP"
    return 0
  }

  if [[ "$SRC" == http* ]]; then
    if ! curl -LSsf --retry 3 --retry-delay 2 "$SRC" -o "$TMP"; then
      echo "[FAIL] $NAME — download failed: $SRC" >&2
      [ "$STRICT" = "1" ] && return 1
      rm -f "$TMP"
      return 0
    fi
  else
    [ -f "$SRC" ] || { _skip "not found: $SRC"; return $?; }
    cp "$SRC" "$TMP"
  fi

  while IFS= read -r line; do
    [[ "$line" =~ ^---\ a/(.+)$ ]] || continue
    t="${BASH_REMATCH[1]}"
    [[ "$t" == "/dev/null" ]] && continue
    [ -f "$t" ] || missing="$missing $t"
  done < "$TMP"
  [ -n "$missing" ] && { _skip "missing:$missing"; return $?; }

  if ! patch -p1 -t --dry-run --forward --quiet < "$TMP" 2>/dev/null; then
    # Forward dry-run failed — tell "already applied" (reverse dry-run succeeds)
    # apart from a genuine conflict (both directions fail).
    # -t/--batch is what keeps this silent: patch never asks "Ignore -R?" when
    # it runs without an operator. (Do not "close stdin" here — patch reads the
    # patch text from that same stdin, so an extra </dev/null makes the reverse
    # dry-run succeed on an empty patch and every conflict looks "applied".)
    if patch -p1 -t --dry-run --reverse --quiet < "$TMP" 2>/dev/null; then
      echo "[SKIP] $NAME — already applied"
      rm -f "$TMP"
      return 0
    fi
    _skip "context mismatch, needs manual review"
    return $?
  fi

  if patch -p1 -t --forward < "$TMP"; then
    echo "[OK]  $NAME"
    rm -f "$TMP"
    return 0
  fi
  _skip "patch command failed"
  return $?
}
