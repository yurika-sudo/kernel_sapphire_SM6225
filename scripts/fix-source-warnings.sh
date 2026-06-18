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

# Fix ext4 trace_printk → pr_debug (DEBUG kernel warning)
EXT4_INLINE="$KERNEL_SRC/fs/ext4/inline.c"
if [ -f "$EXT4_INLINE" ]; then
    sed -i 's/trace_printk(/pr_debug(/g' "$EXT4_INLINE"
    echo "[OK] fixed $EXT4_INLINE"
fi

# Suppress hardcoded trace_printk warning banner
TRACE_C="$KERNEL_SRC/kernel/trace/trace.c"
if [ -f "$TRACE_C" ]; then
    sed -i '/trace_printk() is for debug use only/d' "$TRACE_C"
    sed -i '/pr_warn(".*\*\*/d' "$TRACE_C"
    echo "[OK] fixed $TRACE_C"
fi

# Force-mute verbose printk logging globally
PRINTK_H="$KERNEL_SRC/include/linux/printk.h"
if [ -f "$PRINTK_H" ]; then
    sed -i 's/#define CONSOLE_LOGLEVEL_DEFAULT CONFIG_CONSOLE_LOGLEVEL_DEFAULT/#define CONSOLE_LOGLEVEL_DEFAULT 3/g' "$PRINTK_H"
    echo "[OK] fixed $PRINTK_H"
fi
