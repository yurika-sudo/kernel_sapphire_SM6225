#!/usr/bin/env bash
# setup-ksu.sh — integrate KernelSU-Next (built-in SUSFS) into the kernel source
#
# env:  KERNEL_DIR   kernel source root (the GKI tree)
#       WORK_DIR     dir the *-tag / *-sha / *-version.txt records are written to
#       PINS_FILE    optional override for sources/source-pins.json
# optional env:
#       KSUN_TAG_PIN — exact KSU-Next ref to check out instead of floating branch
#         HEAD. Manual override for bisecting an upstream change; normal builds
#         never set it. Hard-fails if the ref does not exist rather than quietly
#         building branch HEAD.
#
# Everything in here is deliberately fail-fast: a kernel that builds with root
# enabled but SUSFS only half-applied is much worse than a red CI run — it boots,
# grants root and leaks it to every detector on the device.
set -e

: "${KERNEL_DIR:?}"
: "${WORK_DIR:?}"

PINS_FILE="${PINS_FILE:-$(cd "$(dirname "$0")/.." && pwd)/sources/source-pins.json}"

die() { echo "[ERROR] $*" >&2; exit 1; }
note() { echo "[OK] $*"; }

# Pins are the single source of truth for which upstream ref we build against;
# every value has a fallback so a broken pin file degrades to the known-good
# default instead of killing the build.
_pin() {
  local KEY="$1" DEFAULT="$2" VAL=""
  if [ -f "$PINS_FILE" ] && command -v jq >/dev/null 2>&1; then
    VAL=$(jq -r ".${KEY} // empty" "$PINS_FILE" 2>/dev/null || true)
  fi
  case "$VAL" in
    "" | null) echo "$DEFAULT" ;;
    *)         echo "$VAL" ;;
  esac
}

KSUN_REPO=$(  _pin ksun_repo    "pershoot/KernelSU-Next")
KSUN_BRANCH=$(_pin ksun_branch  "dev-susfs")
KSUN_TAG_FB=$(_pin ksun_tag     "v3.4.2")
SUSFS_REPO=$( _pin susfs_repo   "gitlab.com/simonpunk/susfs4ksu")
SUSFS_BRANCH=$(_pin susfs_branch "gki-android13-5.15")

echo "[KSU] $KSUN_REPO @ $KSUN_BRANCH   (SUSFS: $SUSFS_REPO @ $SUSFS_BRANCH)"

git config --global init.defaultBranch main 2>/dev/null || true
git config --global advice.addEmbeddedRepo false 2>/dev/null || true

cd "$KERNEL_DIR"

# ---------------------------------------------------------------------------
# KernelSU-Next driver
#
# We build from pershoot's dev-susfs branch, not KernelSU-Next/KernelSU-Next:
# the built-in (CONFIG_KSU_SUSFS) integration — Kconfig symbols, the susfs_init()
# call in kernel/core/init.c and the inline-hook sucompat — only lives there.
# Upstream dev ships SUSFS as a separate loadable module (susfs_guard_lkm.ko)
# only, which is not what this kernel wants.
# ---------------------------------------------------------------------------
_setup_ksun() {
  rm -rf ./KernelSU ./KernelSU-Next
  if [ -L drivers/kernelsu ]; then
    rm -f drivers/kernelsu
  elif [ -d drivers/kernelsu ]; then
    die "drivers/kernelsu is a stale real directory — remove it and re-run"
  fi

  # Upstream's own integration script: clones the fork, checks out the ref we
  # pass, symlinks drivers/kernelsu and wires drivers/{Makefile,Kconfig}.
  local SETUP_URL="https://raw.githubusercontent.com/${KSUN_REPO}/${KSUN_BRANCH}/kernel/setup.sh"
  curl -LSsf --retry 3 --retry-delay 2 "$SETUP_URL" -o /tmp/ksu_setup.sh \
    || die "could not download KSU setup.sh: $SETUP_URL (branch renamed or upstream gone?)"
  ( cd "$KERNEL_DIR" && bash /tmp/ksu_setup.sh "$KSUN_BRANCH" ) \
    || die "KSU setup.sh failed (checkout of '$KSUN_BRANCH' rejected upstream?)"
  rm -f /tmp/ksu_setup.sh

  [ -d KernelSU-Next/kernel ] || die "KernelSU-Next/kernel missing after setup.sh"
}

# ---------------------------------------------------------------------------
# SUSFS kernel patch (GKI 5.15)
# ---------------------------------------------------------------------------
_patch_namespace_gki_hunk1() {
  # susfs hunk#1 of fs/namespace.c fails on the GKI tree: the extra
  # <trace/hooks/blk.h> include shifts the context lines. The include +
  # extern decls + CL_COPY_MNT_NS define below are all the hunk carried, so
  # applying them by hand is safe and idempotent (guarded).
  grep -q "susfs_def.h" fs/namespace.c && return 0
  python3 - <<'EOF'
txt = open("fs/namespace.c").read()
txt = txt.replace(
    "#include <linux/mnt_idmapping.h>",
    "#include <linux/mnt_idmapping.h>\n\n"
    "#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n"
    "#include <linux/susfs_def.h>\n"
    "#endif",
    1
)
txt = txt.replace(
    '#include "internal.h"',
    '#include "internal.h"\n\n'
    "#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n"
    "extern bool susfs_is_current_ksu_domain(void);\n"
    "extern struct static_key_true susfs_is_sdcard_android_data_not_decrypted;\n\n"
    "#define CL_COPY_MNT_NS BIT(25)\n\n"
    "#endif",
    1
)
open("fs/namespace.c", "w").write(txt)
print("[OK] namespace.c: hunk#1 applied manually")
EOF
}

# Latest susfs_def.h calls current_uid() without including <linux/cred.h>, which
# breaks the build mid-file (everything declared after the call site is unseen).
# Self-deactivates once upstream adds the include.
_patch_susfs_def_h() {
  local DEF_H="include/linux/susfs_def.h"
  [ -f "$DEF_H" ] || return 0
  grep -q "linux/cred.h" "$DEF_H" && return 0
  sed -i '1i #include <linux/cred.h>' "$DEF_H"
  note "susfs_def.h: added linux/cred.h"
}

# The one rejection this tree is known to produce is hunk#1 of fs/namespace.c
# (the include/extern preamble, which _patch_namespace_gki_hunk1 applies by
# hand). Anything else - or that same file rejecting more than that one hunk -
# means patch and tree have genuinely diverged, and the build has to stop.
_susfs_rejects_are_shim_only() {
  python3 - <<'PYEOF'
import glob, re, sys

rejects = glob.glob("**/*.rej", recursive=True)
if not rejects:
    sys.exit(1)

for path in rejects:
    if not path.endswith("fs/namespace.c.rej"):
        print(f"  unexpected reject: {path}", file=sys.stderr)
        sys.exit(1)
    txt = open(path, errors="ignore").read()
    hunks = len(re.findall(r"^@@ ", txt, re.M))
    if hunks != 1 or "CL_COPY_MNT_NS" not in txt or "mnt_idmapping" not in txt:
        print(f"  {path}: {hunks} hunk(s) - not the preamble-only case", file=sys.stderr)
        sys.exit(1)

print("  only the fs/namespace.c preamble hunk failed - the manual shim covers it")
PYEOF
}

_apply_susfs() {
  local PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_${SUSFS_BRANCH}.patch"

  # Shallow clone of just the branch we need; gitlab is the authoritative
  # upstream (the GitHub mirrors are unverified third-party copies).
  git clone --depth=1 "https://${SUSFS_REPO}.git" -b "$SUSFS_BRANCH" susfs4ksu \
    || die "could not clone https://${SUSFS_REPO}.git -b $SUSFS_BRANCH"

  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo unknown)
  SUSFS_COMMIT_LONG=$(git -C susfs4ksu rev-parse HEAD 2>/dev/null || echo unknown)
  SUSFS_VER=$(sed -n 's/^#define SUSFS_VERSION[[:space:]]*"\(.*\)".*/\1/p' \
    "susfs4ksu/kernel_patches/include/linux/susfs.h" 2>/dev/null | head -1)
  SUSFS_VER="${SUSFS_VER:-unknown}"
  note "SUSFS $SUSFS_VER @ $SUSFS_COMMIT ($SUSFS_BRANCH)"

  [ -f "$PATCH" ] || die "SUSFS patch not found in branch $SUSFS_BRANCH: $PATCH"

  if grep -q "CONFIG_KSU_SUSFS" fs/namespace.c; then
    echo "[SKIP] SUSFS kernel patch already applied"
  else
    # -t answers every "File to patch?" prompt with its default instead of waiting
    # on stdin; --forward keeps a re-run harmless. A non-zero status means real
    # rejects, and those stop the build: a kernel with CONFIG_KSU_SUSFS=y but only
    # half its SUSFS code is a root-detection leak, not a warning.
    find . -name '*.rej' -delete 2>/dev/null || true
    if ! patch -p1 -t --forward --fuzz=3 < "$PATCH"; then
      echo "---- rejected hunks ----" >&2
      _susfs_rejects_are_shim_only \
        || die "SUSFS $SUSFS_VER did not apply cleanly to this tree — port the failing hunks, do not ship the build"
      rm -f fs/namespace.c.rej
    fi
    # A patch whose hunks were all skipped also exits 0, so check the payload
    # landed instead of trusting the exit status.
    _patch_namespace_gki_hunk1
    grep -q "CONFIG_KSU_SUSFS" fs/namespace.c \
      || die "SUSFS patch reported success but fs/namespace.c has no hooks"
    grep -q "CL_COPY_MNT_NS" fs/namespace.c \
      || die "fs/namespace.c has no CL_COPY_MNT_NS — SUS_MOUNT would be inert"
  fi

  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/
  _patch_susfs_def_h

  [ -f fs/susfs.c ]            || die "fs/susfs.c missing after copy"
  [ -f include/linux/susfs.h ] || die "include/linux/susfs.h missing after copy"
}

# ---------------------------------------------------------------------------
# Post-conditions — the cheap checks that used to be silent no-ops.
# ---------------------------------------------------------------------------
_verify_integration() {
  # drivers/kernelsu must resolve to the KSU kernel dir and be wired into the
  # build. setup.sh does all three; the fallbacks are for trees where it didn't.
  if [ ! -e drivers/kernelsu/Kconfig ]; then
    ln -sf ../KernelSU-Next/kernel drivers/kernelsu \
      || die "could not link drivers/kernelsu -> ../KernelSU-Next/kernel"
  fi
  grep -q "obj-.*kernelsu" drivers/Makefile || \
    echo 'obj-$(CONFIG_KSU) += kernelsu/' >> drivers/Makefile
  grep -q "kernelsu/Kconfig" drivers/Kconfig || \
    sed -i '/endmenu/i source "drivers/kernelsu/Kconfig"' drivers/Kconfig
  grep -q "kernelsu/Kconfig" drivers/Kconfig \
    || die "drivers/Kconfig: could not insert the kernelsu Kconfig source"

  # SUSFS must be initialised by KSU itself (kernel/core/init.c). This used to be
  # injected by this script into kernel/ksu.c; dev-susfs calls it in-tree now, so
  # a rename upstream has to fail loudly rather than ship an unhidden root.
  grep -R -q "susfs_init()" KernelSU-Next/kernel/ \
    || die "no susfs_init() call in KernelSU-Next/kernel — SUSFS would never start"

  # The Kbuild susfs block is gated on fs/susfs.c existing, so check that too.
  [ -f fs/susfs.c ] || die "fs/susfs.c missing — Kbuild will skip SUSFS entirely"
}

# ---------------------------------------------------------------------------
# Version records — consumed by pack/release tooling and the release body, where
# the KSU version *code* is what the manager APK has to match.
#
# KSU's Kbuild derives its own code as 30000 + <commits on the base branch up
# to the merge-base>, so we compute it the same way; the value baked into the
# kernel and the value used to pick the manager build must be the same number.
# ---------------------------------------------------------------------------
_record_versions() {
  cd "$KERNEL_DIR/KernelSU-Next"
  git fetch --tags -q 2>/dev/null || true

  KSUN_SHA=$(git rev-parse HEAD)
  KSUN_TAG=$(git describe --tags --abbrev=0 HEAD 2>/dev/null | tr -d '[:space:]')
  KSUN_TAG="${KSUN_TAG:-$KSUN_TAG_FB}"

  BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's:-.*::')
  BASE_COMMIT=$(git merge-base "HEAD" "refs/remotes/origin/${BASE_BRANCH}" 2>/dev/null \
    || git merge-base HEAD refs/remotes/origin/dev 2>/dev/null \
    || echo HEAD)
  KSUN_BASE_SHA=$(git rev-parse "$BASE_COMMIT" 2>/dev/null || echo "")
  KSUN_GIT_COUNT=$(git rev-list --count "$BASE_COMMIT" 2>/dev/null || echo "")
  KSUN_VERSION=$([ -n "$KSUN_GIT_COUNT" ] && echo $((30000 + KSUN_GIT_COUNT)) || echo "")

  {
    echo "KSUN_TAG=$KSUN_TAG"
    echo "KSUN_SHA=$KSUN_SHA"
    echo "KSUN_VERSION=$KSUN_VERSION"
    echo "SUSFS_VERSION=$SUSFS_VER"
    echo "SUSFS_COMMIT=$SUSFS_COMMIT"
  } >> "${GITHUB_ENV:-/dev/null}"

  echo "$KSUN_TAG"    > "$WORK_DIR/ksun_tag.txt"
  echo "$KSUN_SHA"    > "$WORK_DIR/ksun_sha.txt"
  echo "$KSUN_BASE_SHA" > "$WORK_DIR/ksun_base_sha.txt"
  echo "$KSUN_VERSION"  > "$WORK_DIR/ksun_version.txt"
  echo "$SUSFS_VER"     > "$WORK_DIR/susfs_version.txt"
  echo "$SUSFS_COMMIT_LONG" > "$WORK_DIR/susfs_commit.txt"

  echo "  KSU-Next : $KSUN_TAG  (sha ${KSUN_SHA:0:8}, version code ${KSUN_VERSION:-?})"
  echo "  SUSFS    : $SUSFS_VER  (commit $SUSFS_COMMIT)"
}

# ---------------------------------------------------------------------------
main() {
  _setup_ksun

  # The verify gate may pin an explicit ref; hard-fail rather than silently
  # building branch HEAD, since a bad pin must surface loudly.
  if [ -n "${KSUN_TAG_PIN:-}" ]; then
    echo "[PIN] KSU-Next: checking out ${KSUN_TAG_PIN} (override)"
    git -C "$KERNEL_DIR/KernelSU-Next" checkout -q "$KSUN_TAG_PIN" \
      || die "KSU-Next: failed to checkout pinned ref '${KSUN_TAG_PIN}'"
  fi

  _apply_susfs
  _verify_integration
  _record_versions

  rm -rf susfs4ksu
  echo "[OK] KSU setup complete: KernelSU-Next ($KSUN_BRANCH) + SUSFS $SUSFS_VER"
}

main "$@"
