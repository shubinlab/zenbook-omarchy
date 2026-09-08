#!/usr/bin/env python3
"""Write a sanitized explicit-package inventory for the system wiki."""

from __future__ import annotations

import subprocess
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "wiki/software/package-inventory.md"
STOCK_FILES = (
    Path("/usr/share/omarchy/install/omarchy-base.packages"),
    Path("/usr/share/omarchy/install/omarchy-other.packages"),
)
PROFILE_DIR = ROOT / "profiles/zenbook-um3406ka/packages"


def names_from_files(paths: tuple[Path, ...]) -> set[str]:
    names: set[str] = set()
    for path in paths:
        if not path.exists():
            continue
        for line in path.read_text().splitlines():
            name = line.split("#", 1)[0].strip().split(maxsplit=1)
            if name:
                names.add(name[0])
    return names


def package_info(names: list[str]) -> dict[str, tuple[str, str]]:
    result = subprocess.run(
        ["pacman", "-Qi", *names], capture_output=True, text=True, check=False
    )
    info: dict[str, tuple[str, str]] = {}
    block: dict[str, str] = {}
    for line in result.stdout.splitlines() + [""]:
        if not line.strip():
            if "Name" in block:
                info[block["Name"]] = (
                    block.get("Version", "unknown"),
                    block.get("Install Reason", "unknown"),
                )
            block = {}
            continue
        if ":" in line:
            key, value = line.split(":", 1)
            block[key.strip()] = value.strip()
    return info


def main() -> None:
    stock = names_from_files(STOCK_FILES)
    profile = names_from_files(tuple(sorted(PROFILE_DIR.glob("*.txt"))))
    explicit = sorted(
        line.split()[0]
        for line in subprocess.check_output(["pacman", "-Qe"], text=True).splitlines()
    )
    info = package_info(explicit)
    installed_all = {
        line.split()[0]
        for line in subprocess.check_output(["pacman", "-Q"], text=True).splitlines()
    }
    rows = []
    for name in explicit:
        version, reason = info.get(name, ("unknown", "unknown"))
        baseline = "stock catalog" if name in stock else "explicit local addition"
        if name in profile:
            baseline += "; profile declared"
        rows.append(f"| `{name}` | `{version}` | {baseline} | {reason} |")

    declared = sorted(profile - installed_all)
    missing = ", ".join(f"`{name}`" for name in declared) or "none"
    OUT.write_text(
        "# Current explicit package inventory\n\n"
        f"**Generated:** {date.today().isoformat()} from `pacman -Qe` and the installed Omarchy package catalogs.\n\n"
        "This page records every explicitly installed package. Dependencies that\n"
        "were installed automatically are represented by their parent package and\n"
        "can be inspected with `pacman -Qi` or `pacman -Qdt`. The stock comparison\n"
        "uses `/usr/share/omarchy/install/omarchy-base.packages` and\n"
        "`omarchy-other.packages`; the second file is a hardware/ISO availability\n"
        "catalog, so it is not proof that every name is installed by default.\n\n"
        f"Explicit packages: **{len(explicit)}**. Stock catalog names: **{len(stock)}**.\n"
        f"Profile-declared names not currently installed: {missing}.\n\n"
        "| Package | Version | Classification | Install reason |\n"
        "|---|---|---|---|\n"
        + "\n".join(rows)
        + "\n\nTo refresh this page after an update:\n\n"
        "```bash\npython tools/update-package-wiki.py\n```\n"
    )


if __name__ == "__main__":
    main()
