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

# Derive symbols from shared config heredocs and gki-legacy-specific blocks.
# Vendor-gated blocks are shared for legacy; KSU-specific blocks are not.
mapfile -t SYMBOLS < <(
  awk '
    function classify_block(    i, has_source, has_ksu, has_other, has_legacy) {
      has_source = has_ksu = has_other = has_legacy = 0
      for (i = 1; i <= depth; i++) {
        if (condition[i] ~ /SOURCE_TYPE/) {
          has_source = 1
          if (condition[i] ~ /"gki-legacy"/)
            has_legacy = 1
        } else if (condition[i] ~ /KSU_TYPE/) {
          has_ksu = 1
        } else if (condition[i] !~ /VENDOR/) {
          has_other = 1
        }
      }
      applicable = has_legacy || (!has_source && !has_ksu && !has_other)
    }
    /^[[:space:]]*if[[:space:]]/ {
      condition[++depth] = $0
      next
    }
    /^[[:space:]]*elif[[:space:]]/ {
      condition[depth] = $0
      next
    }
    /^[[:space:]]*else[[:space:]]/ {
      condition[depth] = $0
      next
    }
    /^[[:space:]]*fi([[:space:]]|$)/ {
      delete condition[depth]
      depth--
      next
    }
    /^[[:space:]]*cat[[:space:]]+>>[[:space:]]+"\$CF"[[:space:]]*<<[[:space:]]*.EOF./ {
      classify_block()
      in_heredoc = 1
      next
    }
    in_heredoc && /^EOF[[:space:]]*$/ {
      in_heredoc = 0
      next
    }
    in_heredoc && applicable && /^[[:space:]]*CONFIG_[A-Za-z0-9_]+=/ {
      sub(/^[[:space:]]*CONFIG_/, "")
      sub(/=.*/, "")
      print
    }
  ' "$SETUP_CONFIGS" | sort -u
)

# Search the applied tree, not patch backup files.
mapfile -t KCONFIG_FILES < <(
  find "$TREE_DIR" -type f -name 'Kconfig*' ! -path "$TREE_DIR/.git/*" \
    ! -name '*.orig' ! -name '*.rej' ! -name '*~' -print | sort
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
unknowns=0
for SYM in "${SYMBOLS[@]}"; do
  checked=$((checked + 1))
  if symbol_is_pending "$SYM"; then
    echo "[FAIL] $SYM is injected for gki-legacy but no legacy patch provides it"
    failures=$((failures + 1))
  elif ! kconfig_provided "$SYM"; then
    echo "[WARN] $SYM is injected for gki-legacy but the symbol does not exist on 5.15.123"
    unknowns=$((unknowns + 1))
  fi
done

echo "legacy config: $checked symbols checked, $failures unbacked, $unknowns unknown"
if [ "$failures" -ne 0 ]; then
  exit 1
fi
exit 0
