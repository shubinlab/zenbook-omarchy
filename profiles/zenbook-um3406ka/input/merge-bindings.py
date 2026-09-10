#!/usr/bin/env python3
"""Replace one managed Hyprland binding block without touching other blocks."""
from __future__ import annotations

import sys
from pathlib import Path

BEGIN = "-- >>> zenbook-omarchy input (managed) >>>"
END = "-- <<< zenbook-omarchy input (managed) <<<"


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} TARGET BLOCK", file=sys.stderr)
        return 2
    target, block_file = map(Path, sys.argv[1:])
    text = target.read_text() if target.exists() else ""
    block = block_file.read_text().strip()
    start = text.find(BEGIN)
    if start >= 0:
        end = text.find(END, start)
        if end < 0:
            raise SystemExit("managed input block has no end marker")
        end += len(END)
        text = text[:start].rstrip() + "\n" + text[end:].lstrip("\n")
    text = text.rstrip() + "\n\n" + block + "\n"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
