#!/usr/bin/env python3
"""Force ntsync onto its 5.15 setxattr path when LINUX_VERSION_CODE is spoofed to 6.12."""
import pathlib
import re
import sys

kernel_src = pathlib.Path(sys.argv[1])

# Detect spoof: check if the kernel tree root Makefile has VERSION=6 PATCHLEVEL=12
_spoofed = False
makefile = kernel_src / "Makefile"
if makefile.is_file():
    text = makefile.read_text()
    if re.search(r"^VERSION = 6$", text, re.MULTILINE) and re.search(r"^PATCHLEVEL = 12$", text, re.MULTILINE):
        _spoofed = True
else:
    print("[WARN] ntsync-compat: Makefile not found in kernel tree; treating as not spoofed", file=sys.stderr)

if not _spoofed:
    print("[SKIP] ntsync-compat: tree is not spoofed; no rewriting needed")
    sys.exit(0)

p = kernel_src / "drivers/misc/ntsync.c"
OLD = "#elif LINUX_VERSION_CODE < KERNEL_VERSION(6,3,0)\n"
NEW = "#elif 1 /* sapphire: real tree is 5.15, LINUX_VERSION_CODE is spoofed to 6.12 */\n"

text = p.read_text()
got = text.count(OLD)
if got != 1:
    sys.exit(f"ntsync-compat: expected 1 match of {OLD.strip()!r}, found {got}")
p.write_text(text.replace(OLD, NEW))
print("ntsync-compat: drivers/misc/ntsync.c: patched 1")
