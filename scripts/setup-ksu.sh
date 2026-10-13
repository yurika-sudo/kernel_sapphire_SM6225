#!/usr/bin/env bash
# setup-ksu.sh — integrate KSU variant + SUSFS into kernel source
# env: KSU_TYPE (ksun|rsku|none), KERNEL_DIR, WORK_DIR
# optional env: KSUN_TAG_PIN, RSKU_TAG_PIN — if set, checkout that exact tag
#   instead of floating branch HEAD. Used only by check-updates.yml's verify
#   gate to test a specific candidate tag before it's committed to
#   source-pins.json. Normal builds never set these, so day-to-day behavior
#   (float + record detected tag) is unchanged.
set -e

: "${KSU_TYPE:?}"
: "${KERNEL_DIR:?}"
: "${WORK_DIR:?}"

git config --global init.defaultBranch main
git config --global advice.addEmbeddedRepo false

cd "$KERNEL_DIR"

_link_ksu_driver() {
  local DIR="$1"   # KernelSU-Next or SukiSU-Ultra
  [ ! -L "drivers/kernelsu" ] && [ ! -d "drivers/kernelsu" ] && \
    ln -sf "../${DIR}" drivers/kernelsu
  grep -q "obj-.*kernelsu" drivers/Makefile || \
    echo 'obj-$(CONFIG_KSU) += kernelsu/' >> drivers/Makefile
  grep -q "kernelsu/Kconfig" drivers/Kconfig || \
    echo 'source "drivers/kernelsu/Kconfig"' >> drivers/Kconfig
}

_fix_susfs_fake_state() {
  # Replace fake_state with selinux_state (pershoot KSU-Next dropped fake_state)
  for f in security/selinux/hooks.c security/selinux/selinuxfs.c; do
    [ -f "$f" ] || continue
    python3 - "$f" <<'EOF'
import sys, subprocess
path = sys.argv[1]
src = open(path).read()
replacements = [
    ('#ifdef CONFIG_KSU_SUSFS\nextern struct selinux_state fake_state;\nextern bool ksu_selinux_hide_running __read_mostly;\n#endif // #ifdef CONFIG_KSU_SUSFS',
     '#ifdef CONFIG_KSU_SUSFS\nextern bool ksu_selinux_hide_running __read_mostly;\n#endif // #ifdef CONFIG_KSU_SUSFS'),
    ('int fake_error = security_context_to_sid(&fake_state, value, size, &tmp_sid, GFP_KERNEL);',
     'int fake_error = security_context_to_sid(&selinux_state, value, size, &tmp_sid, GFP_KERNEL);'),
    ('extern struct selinux_state fake_state;\n',
     ''),
    ('security_context_to_sid(&fake_state, buf, size, &sid, GFP_KERNEL)',
     'security_context_to_sid(&selinux_state, buf, size, &sid, GFP_KERNEL)'),
    ('security_sid_to_context(&fake_state, sid, &canon, &len)',
     'security_sid_to_context(&selinux_state, sid, &canon, &len)'),
    ('security_context_str_to_sid(&fake_state, scon, &ssid, GFP_KERNEL)',
     'security_context_str_to_sid(&selinux_state, scon, &ssid, GFP_KERNEL)'),
    ('security_context_str_to_sid(&fake_state, tcon, &tsid, GFP_KERNEL)',
     'security_context_str_to_sid(&selinux_state, tcon, &tsid, GFP_KERNEL)'),
    ('security_compute_av_user(&fake_state, ssid, tsid, tclass, &avd)',
     'security_compute_av_user(&selinux_state, ssid, tsid, tclass, &avd)'),
]
for old, new in replacements:
    if old in src:
        src = src.replace(old, new)
open(path, 'w').write(src)
result = subprocess.run(['grep', '-n', 'fake_state', path], capture_output=True, text=True)
if result.stdout:
    print(f'[FAIL] fake_state still in {path}')
else:
    print(f'[OK] fake_state -> selinux_state in {path}')
EOF
  done
}

_inject_susfs_init() {
  local KSU_C="$1"
  [ ! -f "$KSU_C" ] && return 0
  grep -q "susfs_init" "$KSU_C" && return 0

  grep -q "#include <linux/susfs.h>" "$KSU_C" || \
    sed -i '/#include <linux\/fs\.h>/a #include <linux\/susfs.h>/' "$KSU_C" || true
  grep -q "susfs_init()" "$KSU_C" || \
    sed -i '/ksu_core_init();/a \\tsusfs_init();' "$KSU_C" || \
    sed -i '/int __init ksu_init(/,/^}/{ /return 0;/i \\tsusfs_init(); }' "$KSU_C" || true
  echo "[OK] susfs_init injected into $KSU_C"
}

# KernelSU-Next
_pin_susfs_lvc() {
  # kernel-release-spoof sets VERSION=6 PATCHLEVEL=12, so susfs.c took 6.x branches.
  # Pin LINUX_VERSION_CODE after the last include, same pattern as nomount.h.
  local F="fs/susfs.c"
  [ -f "$F" ] || return 0
  grep -q "sapphire: pin LINUX_VERSION_CODE" "$F" && return 0
  if [ "$(grep -c '^#include "mount.h"$' "$F")" != 1 ]; then
    echo "[FAIL] _pin_susfs_lvc: expected exactly 1 mount.h include in $F"
    return 1
  fi
  sed -i '/^#include "mount.h"$/a /* sapphire: pin LINUX_VERSION_CODE to real 5.15.220 (spoofed to 6.12) */\n#undef LINUX_VERSION_CODE\n#define LINUX_VERSION_CODE KERNEL_VERSION(5, 15, 220)' "$F"
  echo "[OK] susfs.c: LINUX_VERSION_CODE pinned to 5.15.220"
}

_patch_susfs_def_h() {
  # Latest susfs_def.h calls current_uid() without <linux/cred.h>.
  # Breaks compile mid-file — everything declared after call site is unseen.
  local DEF_H="include/linux/susfs_def.h"
  [ -f "$DEF_H" ] || return 0
  grep -q "linux/cred.h" "$DEF_H" && return 0
  sed -i '1i #include <linux/cred.h>' "$DEF_H"
  echo "[OK] susfs_def.h: added linux/cred.h"
}


_patch_namespace_gki_hunk1() {
  # susfs patch hunk#1 fails on GKI: trace/hooks/blk.h shifts context lines.
  # Manually applies the rejected include + extern decls + CL_COPY_MNT_NS define.
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

_fix_ksu_umount_missing_set() {
  # SukiSU-Ultra `builtin` sync commit d13e8a75 (2026-09-01, "Sync with the
  # official KernelSU main repo") dropped kernel_umount_feature_set()'s
  # definition but left the struct reference to it -- breaks compile.
  # Still unfixed on builtin HEAD as of 2026-09-04. Self-deactivates once
  # upstream restores the definition (grep guard below).
  local KU_C="$1"
  [ -f "$KU_C" ] || return 0
  grep -q "kernel_umount_feature_set" "$KU_C" || return 0
  grep -q "static int kernel_umount_feature_set" "$KU_C" && return 0
  python3 - "$KU_C" <<'EOF'
import sys
path = sys.argv[1]
txt = open(path).read()
marker = "static int kernel_umount_feature_get(u64 *value)"
idx = txt.find(marker)
if idx == -1:
    print("[WARN] kernel_umount.c: get_handler anchor not found, skipping umount fix")
    sys.exit(0)
end = txt.find("\n}\n", idx) + 3
insert = (
    "\nstatic int kernel_umount_feature_set(u64 value)\n"
    "{\n"
    "    bool enable = value != 0;\n"
    "    ksu_kernel_umount_enabled = enable;\n"
    "    pr_info(\"kernel_umount: set to %d\\n\", enable);\n"
    "    return 0;\n"
    "}\n"
)
txt = txt[:end] + insert + txt[end:]
open(path, "w").write(txt)
print("[OK] kernel_umount.c: restored missing kernel_umount_feature_set")
EOF
}

_fix_susfs_exec_suki() {
  # ShirkNeko SUSFS patch injects ksu_handle_execveat / ksu_install_su_fd
  # hooks into fs/exec.c, but SukiSU-Ultra uses a different hook mechanism
  # (syscall_event_bridge.c) and never ships these symbols. Strip all
  # CONFIG_KSU_SUSFS blocks from exec.c except the susfs_def.h include.
  # Self-deactivates if exec.c no longer has the markers.
  local EXEC_C="fs/exec.c"
  [ -f "$EXEC_C" ] || return 0
  grep -q "ksu_install_su_fd\|ksu_handle_execveat" "$EXEC_C" || return 0
  python3 - <<PYEOF "$EXEC_C"
import sys, re
path = sys.argv[1]
txt = open(path).read()

txt = re.sub(
    r'#ifdef CONFIG_KSU_SUSFS\nextern struct static_key_true ksu_su_compat_enabled;.*?#endif\n\n',
    '', txt, count=1, flags=re.DOTALL)
txt = re.sub(
    r'#ifdef CONFIG_KSU_SUSFS\n\s*bool is_su_session = false;\n#endif[^\n]*\n',
    '', txt, count=1, flags=re.DOTALL)
txt = re.sub(
    r'#ifdef CONFIG_KSU_SUSFS\n\s*if [(]likely[(]susfs_is_current_proc_no_su.*?#endif\n',
    '', txt, count=1, flags=re.DOTALL)
txt = re.sub(
    r'#ifdef CONFIG_KSU_SUSFS\n\s*if [(]unlikely[(]is_su_session.*?#endif[^\n]*\n',
    '', txt, count=1, flags=re.DOTALL)

open(path, 'w').write(txt)
print("[OK] exec.c: stripped SukiSU-incompatible SUSFS hooks")
PYEOF
}

# Checkout an exact tag/ref in the given dir if a pin override was supplied.
# Hard-fails (not falls back) — this path is only used by the verify gate,
# so a bad pin should surface loudly rather than silently building HEAD.
_checkout_pin() {
  local DIR="$1" PIN="$2" LABEL="$3"
  [ -z "$PIN" ] && return 0
  echo "[PIN] ${LABEL}: checking out ${PIN} (override)"
  git -C "$DIR" checkout -q "$PIN" || {
    echo "[ERROR] ${LABEL}: failed to checkout pinned ref '${PIN}'"; exit 1;
  }
}

_pin_lvc_after() {
  local F="$1" ANCHOR="$2"
  [ -f "$F" ] || { echo "[FAIL] _pin_lvc_after: $F not found"; return 1; }
  grep -q "sapphire: pin LINUX_VERSION_CODE" "$F" && return 0
  if [ "$(grep -cFx -- "$ANCHOR" "$F")" != 1 ]; then
    echo "[FAIL] _pin_lvc_after: expected exactly 1 '$ANCHOR' in $F"
    return 1
  fi
  awk -v a="$ANCHOR" '{ print } $0 == a { print "/* sapphire: pin LINUX_VERSION_CODE to real 5.15.220 (spoofed to 6.12) */"; print "#undef LINUX_VERSION_CODE"; print "#define LINUX_VERSION_CODE KERNEL_VERSION(5, 15, 220)" }' "$F" > "$F.sapphire.tmp" \
    && cat "$F.sapphire.tmp" > "$F" && rm -f "$F.sapphire.tmp"
  echo "[OK] $F: LINUX_VERSION_CODE pinned to 5.15.220"
}

_pin_ksun_lvc() {
  # KernelSU-Next takes the 6.12 LSM static_call path under the release spoof.
  _pin_lvc_after "KernelSU-Next/kernel/hook/lsm_hook.h" '#include <linux/version.h>' || return 1
  _pin_lvc_after "KernelSU-Next/kernel/hook/lsm_hook.c" '#include "klog.h" // IWYU pragma: keep'
}

if [ "$KSU_TYPE" = "ksun" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu ./KernelSU-Next
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" \
    | bash -s dev-susfs
  [ -d "KernelSU-Next" ] || { echo "[ERROR] KernelSU-Next not found"; exit 1; }

  cd KernelSU-Next
  git fetch --tags 2>/dev/null || true
  _checkout_pin "." "${KSUN_TAG_PIN:-}" "KSU-Next"
  KSUN_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
  KSUN_SHA=$(git rev-parse HEAD)
  echo "KSUN_TAG=$KSUN_TAG"    >> "${GITHUB_ENV:-/dev/null}"
  echo "KSUN_SHA=$KSUN_SHA"    >> "${GITHUB_ENV:-/dev/null}"
  echo "$KSUN_TAG"                  > "$WORK_DIR/ksun_tag.txt"
  echo "$KSUN_SHA"                  > "$WORK_DIR/ksun_sha.txt"
  _ksun_ver=$(grep -rh "^#define KSU_VERSION\b" kernel/ 2>/dev/null \
  | awk 'NR==1{print $NF}' | tr -d '[:space:]')
  echo "${_ksun_ver:-}" > "$WORK_DIR/ksun_version.txt"
  cd ..

  # SUSFS — simonpunk main branch (compatible with KSU-Next)
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android13-5.15
  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "SUSFS_COMMIT=$SUSFS_COMMIT" >> "${GITHUB_ENV:-/dev/null}"
  echo "[OK] SUSFS commit: $SUSFS_COMMIT"

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --forward --fuzz=3 < "$SUSFS_PATCH" || true
  _patch_namespace_gki_hunk1
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/
  _patch_susfs_def_h
  _pin_susfs_lvc
  _pin_ksun_lvc
  _fix_susfs_fake_state

  _inject_susfs_init "KernelSU-Next/kernel/ksu.c"
  _link_ksu_driver "KernelSU-Next"
  rm -rf susfs4ksu

# SukiSU-Ultra
elif [ "$KSU_TYPE" = "rsku" ]; then
  rm -rf ./KernelSU ./drivers/kernelsu ./ReSukiSU
  git clone --depth=1 https://github.com/ReSukiSU/ReSukiSU.git
  [ -d "ReSukiSU" ] || { echo "[ERROR] ReSukiSU not found"; exit 1; }

  cd ReSukiSU
  git fetch --tags 2>/dev/null || true
  git fetch --deepen=50 2>/dev/null || true
  _checkout_pin "." "${RSKU_TAG_PIN:-}" "ReSukiSU"
  RSKU_SHA=$(git rev-parse HEAD)
  # 1. Exact match on HEAD (HEAD is directly tagged).
  # 2. Nearest ancestor tag via describe (HEAD is ahead of last tag — most common case
  #    with depth=1 clones where main has moved past the release tag).
  # 3. SHA-exact match via ls-remote as last resort.
  RSKU_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null | tr -d '[:space:]')
  RSKU_TAG=${RSKU_TAG:-$(git describe --tags --abbrev=0 HEAD 2>/dev/null | tr -d '[:space:]')}
  RSKU_TAG=${RSKU_TAG:-$(git ls-remote --tags https://github.com/ReSukiSU/ReSukiSU.git 2>/dev/null | awk -v sha="$RSKU_SHA" '/\^\{\}$/ {next} $0 ~ sha {match($2,/refs\/tags\/(.+)/,a); print a[1]}' | tail -1)}
  RSKU_TAG=${RSKU_TAG:-unknown}
  echo "RSKU_TAG=$RSKU_TAG"    >> "${GITHUB_ENV:-/dev/null}"
  echo "RSKU_SHA=$RSKU_SHA"    >> "${GITHUB_ENV:-/dev/null}"
  echo "$RSKU_TAG"                  > "$WORK_DIR/rsku_tag.txt"
  echo "$RSKU_SHA"                  > "$WORK_DIR/rsku_sha.txt"
  _rsku_ver=$(grep -rh "^#define KSU_VERSION\b" kernel/ 2>/dev/null \
  | awk 'NR==1{print $NF}' | tr -d '[:space:]')
  echo "${_rsku_ver:-}" > "$WORK_DIR/rsku_version.txt"
  cd ..

  # SUSFS — simonpunk main branch (ReSukiSU already ships SUSFS built-in)
  git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android13-5.15
  SUSFS_COMMIT=$(git -C susfs4ksu rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "SUSFS_COMMIT=$SUSFS_COMMIT" >> "${GITHUB_ENV:-/dev/null}"
  echo "[OK] SUSFS commit: $SUSFS_COMMIT"

  SUSFS_PATCH="susfs4ksu/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
  [ -f "$SUSFS_PATCH" ] && patch -p1 --forward --fuzz=3 < "$SUSFS_PATCH" || true
  _patch_namespace_gki_hunk1
  mkdir -p fs include/linux
  cp -f susfs4ksu/kernel_patches/fs/*            fs/
  cp -f susfs4ksu/kernel_patches/include/linux/* include/linux/
  _patch_susfs_def_h
  _pin_susfs_lvc
  _fix_susfs_fake_state

  _inject_susfs_init "ReSukiSU/kernel/ksu.c"
  # ReSukiSU keeps its kernel integration under ReSukiSU/kernel/ (not root),
  # so link that subdirectory directly instead of using _link_ksu_driver.
  [ ! -L "drivers/kernelsu" ] && [ ! -d "drivers/kernelsu" ] && \
    ln -sf "../ReSukiSU/kernel" drivers/kernelsu
  grep -q "obj-.*kernelsu" drivers/Makefile || \
    echo 'obj-$(CONFIG_KSU) += kernelsu/' >> drivers/Makefile
  grep -q "kernelsu/Kconfig" drivers/Kconfig || \
    echo 'source "drivers/kernelsu/Kconfig"' >> drivers/Kconfig
  rm -rf susfs4ksu

fi

echo "[OK] KSU setup complete: $KSU_TYPE"
