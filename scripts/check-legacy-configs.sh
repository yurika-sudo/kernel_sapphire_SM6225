#!/usr/bin/env bash
# check-legacy-configs.sh -- catch legacy configs injected without a legacy patch
# Exits non-zero when a gki-legacy config symbol is not provided by the legacy set.
# POSIX-ish bash, offline; never runs make.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TREE_DIR="${1:-/root/gki-common-5.15-legacy}"
SETUP_CONFIGS="$SCRIPT_DIR/setup-configs.sh"
COMMON_DIR="$REPO_DIR/patches/common"
PENDING_FILE="$REPO_DIR/patches/gki-legacy/PENDING.txt"

if [ ! -f "$SETUP_CONFIGS" ]; then
  echo "[FAIL] missing setup-configs.sh: $SETUP_CONFIGS" >&2
  exit 1
fi
if [ ! -d "$TREE_DIR" ]; then
  echo "[FAIL] kernel tree does not exist: $TREE_DIR" >&2
  exit 1
fi
if [ ! -f "$PENDING_FILE" ]; then
  echo "[FAIL] missing legacy pending list: $PENDING_FILE" >&2
  exit 1
fi

# Derive the symbols from the existing per-source-type blocks in setup-configs.sh.
# We collect only the blocks whose condition names gki-legacy, not the common block.
mapfile -t SYMBOLS < <(
  awk '
    /^[[:space:]]*(if|elif)[[:space:]].*SOURCE_TYPE/ {
      legacy_block = ($0 ~ /"gki-legacy"/)
    }
    /^[[:space:]]*fi([[:space:]]|$)/ {
      legacy_block = 0
    }
    legacy_block && /^[[:space:]]*CONFIG_[A-Za-z0-9_]+=y[[:space:]]*$/ {
      sub(/^[[:space:]]*CONFIG_/, "")
      sub(/=y[[:space:]]*$/, "")
      print
    }
  ' "$SETUP_CONFIGS" | sort -u
)

# Search the applied tree, not patch backup files.
mapfile -t KCONFIG_FILES < <(
  for DIR in "$TREE_DIR"/include "$TREE_DIR"/kernel "$TREE_DIR"/net \
             "$TREE_DIR"/block "$TREE_DIR"/drivers "$TREE_DIR"/fs \
             "$TREE_DIR"/mm "$TREE_DIR"/crypto "$TREE_DIR"/init "$TREE_DIR"/arch; do
    [ -d "$DIR" ] || continue
    find "$DIR" -type f -name 'Kconfig*' ! -name '*.orig' ! -name '*.rej' ! -name '*~' -print
  done | sort
)

# A pending patch implements a symbol when PENDING.txt or the patch names it.
# The pending CFS bandwidth entry names both symbols it gates.
symbol_is_pending() {
  local sym=$1
  local line patch patch_file
  while IFS= read -r line; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    if grep -qE "(^|[^A-Za-z0-9_])CONFIG_${sym}([^A-Za-z0-9_]|$)" <<< "$line"; then
      return 0
    fi
    patch="${line%% - *}"
    patch_file="$COMMON_DIR/$patch"
    [ -f "$patch_file" ] || continue
    if grep -qE "(^|[^A-Za-z0-9_])CONFIG_${sym}([^A-Za-z0-9_]|$)" "$patch_file" || \
       grep -qE "^[[:space:]]*config[[:space:]]+${sym}([[:space:]]|$)" "$patch_file"; then
      return 0
    fi
  done < "$PENDING_FILE"
  return 1
}

kconfig_provided() {
  local sym=$1
  [ "${#KCONFIG_FILES[@]}" -gt 0 ] || return 1
  grep -qE "^[[:space:]]*(menuconfig|config)[[:space:]]+${sym}([[:space:]]|$)" "${KCONFIG_FILES[@]}"
}

checked=0
failures=0
for SYM in "${SYMBOLS[@]}"; do
  checked=$((checked + 1))
  if symbol_is_pending "$SYM" || ! kconfig_provided "$SYM"; then
    echo "[FAIL] $SYM is injected for gki-legacy but no legacy patch provides it"
    failures=$((failures + 1))
  else
    echo "[OK] $SYM is provided by the legacy set"
  fi
done

if [ "$failures" -ne 0 ]; then
  echo "legacy config: $checked symbols checked, $failures unbacked"
  exit 1
fi

echo "legacy config: $checked symbols checked, all provided"
exit 0
