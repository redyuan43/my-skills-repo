#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path


def main() -> int:
    skill_dir = Path(__file__).resolve().parent.parent
    repo_root = skill_dir.parent
    target = repo_root / "scripts" / "skill_quality_gate.py"
    if not target.exists():
        print(f"Error: missing target script: {target}", file=sys.stderr)
        return 1

    os.execv(sys.executable, [sys.executable, str(target), *sys.argv[1:]])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
