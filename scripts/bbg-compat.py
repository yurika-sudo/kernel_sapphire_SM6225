#!/usr/bin/env python3
"""Force Baseband-guard onto its 5.15 code paths when LINUX_VERSION_CODE is spoofed to 6.12."""
import pathlib
import re
import sys

# argv[1] is the Baseband-guard directory (kept as-is for rewrite targets)
bbg_dir = pathlib.Path(sys.argv[1])

# Walk UP from bbg_dir to find kernel tree root Makefile containing "VERSION = " line
makefile_path = None
p = bbg_dir
while True:
    mp = p / "Makefile"
    if mp.is_file():
        text = mp.read_text()
        if re.search(r"^VERSION = ", text, re.MULTILINE):
            makefile_path = mp
            break
    # Move up one level, stop at filesystem root
    if p.parent == p:
        break
    p = p.parent

# Fall back to cwd Makefile if not found walking up
if makefile_path is None:
    mc = pathlib.Path("Makefile")
    if mc.is_file():
        text = mc.read_text()
        if re.search(r"^VERSION = ", text, re.MULTILINE):
            makefile_path = mc

# If still no Makefile, treat as not spoofed
if makefile_path is None:
    print("[WARN] bbg-compat: Makefile not found in kernel tree; treating as not spoofed", file=sys.stderr)
    sys.exit(0)

# Detect spoof: check if the Makefile has VERSION=6 PATCHLEVEL=12
_spoofed = False
text = makefile_path.read_text()
if re.search(r"^VERSION = 6$", text, re.MULTILINE) and re.search(r"^PATCHLEVEL = 12$", text, re.MULTILINE):
    _spoofed = True

if not _spoofed:
    print("[SKIP] bbg-compat: tree is not spoofed; no rewriting needed")
    sys.exit(0)

NEW = "#if 0 /* sapphire: real tree is 5.15, LINUX_VERSION_CODE is spoofed to 6.12 */"
EDITS = [
    ("kernel_compat.h", "#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,8,0)", 2),
    ("baseband_guard.c", "#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,9,0)", 1),
    ("tracing/kernel_compat.h", "#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,4,0)", 1),
]

for rel, old, want in EDITS:
    p = bbg_dir / rel
    text = p.read_text()
    got = text.count(old)
    if got != want:
        sys.exit(f"bbg-compat: {rel}: expected {want} match(es) of {old!r}, found {got}")
    p.write_text(text.replace(old, NEW))
    print(f"bbg-compat: {rel}: patched {got}")
