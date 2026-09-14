#!/usr/bin/env python3
"""Check relative Markdown links without fetching external URLs."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


LINK_RE = re.compile(r"(?<!!)\[[^\]]+\]\(([^)\s]+)(?:\s+[^)]*)?\)")


def local_links(root: Path):
    for document in sorted(root.rglob("*.md")):
        relative_parts = document.relative_to(root).parts
        if ".git" in relative_parts or "runs" in relative_parts:
            continue
        text = document.read_text(encoding="utf-8", errors="replace")
        for match in LINK_RE.finditer(text):
            target = match.group(1).strip("<>")
            if not target or "://" in target or target.startswith("#"):
                continue
            yield document, target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        print(f"markdown-links: root is not a directory: {root}", file=sys.stderr)
        return 2

    checked = 0
    missing = []
    for document, target in local_links(root):
        checked += 1
        path = (document.parent / target.split("#", 1)[0]).resolve()
        if not path.exists():
            missing.append(f"{document.relative_to(root)} -> {target}")

    if missing:
        for item in missing:
            print(f"markdown-links: missing {item}", file=sys.stderr)
        return 1

    print(f"markdown-links: checked {checked} local links; PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
