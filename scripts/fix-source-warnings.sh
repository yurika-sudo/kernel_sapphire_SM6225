#!/bin/bash
set -e

KERNEL_SRC="${1:-kernel_src}"

# Fix bpf_doc.py SyntaxWarnings
BPF_DOC="$KERNEL_SRC/scripts/bpf_doc.py"
if [ -f "$BPF_DOC" ]; then
    sed -i "s/re\.compile('\(.*\)')/re.compile(r'\1')/g" "$BPF_DOC"
    sed -i 's/\*\*\\ /\*\*\\\\ /g' "$BPF_DOC"
    echo "[OK] fixed $BPF_DOC"
fi

# Fix sail_mbox.h C++ style comments
SAIL_MBOX="$KERNEL_SRC/include/uapi/linux/sail_mbox.h"
if [ -f "$SAIL_MBOX" ]; then
    sed -i 's|[[:space:]]// \(.*\)$| /* \1 */|' "$SAIL_MBOX"
    echo "[OK] fixed $SAIL_MBOX"
fi
