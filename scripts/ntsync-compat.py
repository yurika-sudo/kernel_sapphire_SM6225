#!/usr/bin/env python3
"""Force ntsync onto its 5.15 setxattr path when LINUX_VERSION_CODE is spoofed to 6.12."""
import pathlib
import sys

p = pathlib.Path(sys.argv[1]) / "drivers/misc/ntsync.c"
OLD = "#elif LINUX_VERSION_CODE < KERNEL_VERSION(6,3,0)\n"
NEW = "#elif 1 /* sapphire: real tree is 5.15, LINUX_VERSION_CODE is spoofed to 6.12 */\n"

text = p.read_text()
got = text.count(OLD)
if got != 1:
    sys.exit(f"ntsync-compat: expected 1 match of {OLD.strip()!r}, found {got}")
p.write_text(text.replace(OLD, NEW))
print("ntsync-compat: drivers/misc/ntsync.c: patched 1")
