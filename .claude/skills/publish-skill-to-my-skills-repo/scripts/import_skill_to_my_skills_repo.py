#!/usr/bin/env python3
"""
Copy a local Codex skill into my-skills-repo format and print a README entry template.

This script intentionally does NOT edit README.md automatically.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path


EXCLUDE_NAMES = {
    ".git",
    "__pycache__",
    ".DS_Store",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--source", required=True, help="Source skill directory (e.g. ~/.codex/skills/<name>)")
    p.add_argument("--target-repo", required=True, help="Path to local my-skills-repo clone")
    p.add_argument("--include-agents", action="store_true", help="Also copy agents/ directory")
    p.add_argument("--overwrite", action="store_true", help="Overwrite existing target skill directory")
    return p.parse_args()


def should_skip(rel: Path, include_agents: bool) -> bool:
    parts = set(rel.parts)
    if parts & EXCLUDE_NAMES:
        return True
    if not include_agents and rel.parts and rel.parts[0] == "agents":
        return True
    return False


def collect_files(src: Path, include_agents: bool) -> list[Path]:
    files: list[Path] = []
    for p in sorted(src.rglob("*")):
        rel = p.relative_to(src)
        if should_skip(rel, include_agents):
            continue
        if p.is_file():
            files.append(rel)
    return files


def main() -> None:
    args = parse_args()
    src = Path(os.path.expanduser(args.source)).resolve()
    repo = Path(os.path.expanduser(args.target_repo)).resolve()

    if not src.is_dir():
        sys.exit(f"Source skill directory not found: {src}")
    if not repo.is_dir():
        sys.exit(f"Target repo directory not found: {repo}")
    if not (repo / ".git").exists():
        sys.exit(f"Target repo does not look like a git repo: {repo}")
    if not (src / "SKILL.md").exists():
        sys.exit(f"Source skill is missing SKILL.md: {src}")

    skill_name = src.name
    dst = repo / skill_name

    if dst.exists():
        if not args.overwrite:
            sys.exit(f"Target skill already exists: {dst} (use --overwrite to replace)")
        shutil.rmtree(dst)

    files = collect_files(src, args.include_agents)
    if not files:
        sys.exit("No files to copy after exclusions.")

    for rel in files:
        out = dst / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / rel, out)

    print(f"COPIED_SKILL {skill_name}")
    print(f"SOURCE {src}")
    print(f"TARGET {dst}")
    print("COPIED_FILES")
    for rel in files:
        print(f"- {rel.as_posix()}")

    print("\nREADME_ENTRY_TEMPLATE")
    print(f"### <编号>. {skill_name}")
    print("**功能：** [填写技能功能]")
    print("**用途：** [填写触发场景/用途]")
    print("**文件：**")
    for rel in files:
        print(f"- `{rel.as_posix()}` - [填写说明]")


if __name__ == "__main__":
    main()
