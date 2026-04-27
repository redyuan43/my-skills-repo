#!/usr/bin/env python3
"""Install D-DIN fonts into the current user's fontconfig directory."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path


FONT_URL = "https://fontlibrary.org/assets/downloads/d-din/39fc8c3de156292478f87c2ff0b96df2/d-din.zip"
FONT_DIR = Path.home() / ".local" / "share" / "fonts" / "D-DIN"
FILES_TO_INSTALL = {
    "D-DIN.otf",
    "D-DIN-Bold.otf",
    "D-DIN-Italic.otf",
    "D-DINCondensed.otf",
    "D-DINCondensed-Bold.otf",
    "D-DINExp.otf",
    "D-DINExp-Bold.otf",
    "D-DINExp-Italic.otf",
    "OFL-1.1.txt",
    "COPYING.txt",
    "README",
}


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def fc_match(name: str) -> str:
    if not shutil.which("fc-match"):
        return ""
    result = run(["fc-match", name])
    return result.stdout.strip()


def has_ddin() -> bool:
    return "D-DIN" in fc_match("D\\-DIN") or "D-DIN" in fc_match("D-DIN")


def download_zip(path: Path) -> None:
    with urllib.request.urlopen(FONT_URL, timeout=30) as response:
        path.write_bytes(response.read())


def install(force: bool = False) -> int:
    if has_ddin() and not force:
        print(fc_match("D\\-DIN"))
        print("D-DIN already available.")
        return 0

    FONT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        zip_path = Path(tmp) / "d-din.zip"
        download_zip(zip_path)
        with zipfile.ZipFile(zip_path) as archive:
            for member in archive.namelist():
                if Path(member).name in FILES_TO_INSTALL:
                    archive.extract(member, FONT_DIR)

    if shutil.which("fc-cache"):
        cache = run(["fc-cache", "-f", str(FONT_DIR.parent)])
        if cache.returncode != 0:
            print(cache.stderr, file=sys.stderr)
            return cache.returncode

    print(fc_match("D\\-DIN") or fc_match("D-DIN"))
    print(f"Installed D-DIN to {FONT_DIR}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="reinstall even if D-DIN is already available")
    parser.add_argument("--check", action="store_true", help="only check whether D-DIN is available")
    args = parser.parse_args()

    if args.check:
        match = fc_match("D\\-DIN") or fc_match("D-DIN")
        print(match or "fontconfig not available")
        return 0 if has_ddin() else 1
    return install(force=args.force)


if __name__ == "__main__":
    raise SystemExit(main())
