#!/usr/bin/env python3
"""Force Baseband-guard onto its 5.15 code paths when LINUX_VERSION_CODE is spoofed to 6.12."""
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
NEW = "#if 0 /* sapphire: real tree is 5.15, LINUX_VERSION_CODE is spoofed to 6.12 */"
EDITS = [
    ("kernel_compat.h", "#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,8,0)", 2),
    ("baseband_guard.c", "#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,9,0)", 1),
    ("tracing/kernel_compat.h", "#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,4,0)", 1),
]

for rel, old, want in EDITS:
    p = root / rel
    text = p.read_text()
    got = text.count(old)
    if got != want:
        sys.exit(f"bbg-compat: {rel}: expected {want} match(es) of {old!r}, found {got}")
    p.write_text(text.replace(old, NEW))
    print(f"bbg-compat: {rel}: patched {got}")
