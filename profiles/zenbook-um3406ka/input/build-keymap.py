#!/usr/bin/env python3
"""Turn a compiled three-group XKB map into the Zenbook map."""
from __future__ import annotations

import re
import sys

text = sys.stdin.read()
pattern = re.compile(r"(key <RCTL>\s*\{\s*\[)\s*Control_R(\s*,|\s*\])")
text, count = pattern.subn(r"\1 F13\2", text, count=1)
if count != 1:
    raise SystemExit("could not find the compiled Right Ctrl definition")
text, count = re.subn(
    r"modifier_map Control \{\s*<LCTL>\s*,\s*<RCTL>\s*\};",
    "modifier_map Control { <LCTL> };",
    text,
    count=1,
)
if count != 1:
    raise SystemExit("could not remove Right Ctrl from the Control modifier map")
sys.stdout.write(text)
