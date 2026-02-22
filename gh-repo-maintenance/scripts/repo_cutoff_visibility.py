#!/usr/bin/env python3
"""
List or hide GitHub repositories created before a cutoff date using gh CLI.

Examples:
  python3 scripts/repo_cutoff_visibility.py --before 2021-01-01 --action list
  python3 scripts/repo_cutoff_visibility.py --before 2021-01-01 --action hide --apply
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--owner", default=None, help="GitHub owner/org. Defaults to current gh account.")
    p.add_argument("--limit", type=int, default=300, help="Max repos to fetch (default: 300)")
    p.add_argument("--before", required=True, help="Cutoff date YYYY-MM-DD; matches createdAt < cutoff")
    p.add_argument("--action", choices=["list", "hide"], default="list")
    p.add_argument("--apply", action="store_true", help="Execute mutations for hide action")
    return p.parse_args()


def fetch_repos(limit: int) -> list[dict]:
    fields = "name,nameWithOwner,isPrivate,visibility,isFork,createdAt,updatedAt"
    cp = run(["gh", "repo", "list", "--limit", str(limit), "--json", fields])
    if cp.returncode != 0:
        sys.stderr.write(cp.stderr or cp.stdout or "gh repo list failed\n")
        sys.exit(cp.returncode)
    return json.loads(cp.stdout)


def filter_by_cutoff(repos: list[dict], cutoff: datetime, owner: str | None) -> list[dict]:
    out = []
    for r in repos:
        if owner and not r["nameWithOwner"].lower().startswith(owner.lower() + "/"):
            continue
        created = datetime.fromisoformat(r["createdAt"].replace("Z", "+00:00"))
        if created < cutoff:
            out.append(r)
    return sorted(out, key=lambda x: x["createdAt"])


def print_targets(targets: list[dict], cutoff_raw: str) -> None:
    print(f"CUTOFF {cutoff_raw} (createdAt < {cutoff_raw}T00:00:00Z)")
    print(f"COUNT {len(targets)}")
    for r in targets:
        print(
            f"{r['createdAt'][:10]} "
            f"{r['visibility']:<7} "
            f"{'FORK' if r['isFork'] else 'OWN ':<4} "
            f"{r['nameWithOwner']}"
        )


def hide_targets(targets: list[dict], apply: bool) -> int:
    if not apply:
        print("DRY_RUN Use --apply to execute visibility changes.")
        for r in targets:
            print(f"WOULD_HIDE {r['nameWithOwner']}")
        return 0

    failures = 0
    for r in targets:
        repo = r["nameWithOwner"]
        cp = run(["gh", "api", "-X", "PATCH", f"repos/{repo}", "-F", "private=true", "--silent"])
        if cp.returncode == 0:
            print(f"PRIVATE_OK {repo}")
            continue
        msg = (cp.stderr or cp.stdout or "").strip().replace("\n", " ")
        print(f"PRIVATE_FAIL {repo} :: {msg}")
        failures += 1
    return failures


def main() -> None:
    args = parse_args()
    try:
        cutoff = datetime.strptime(args.before, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError:
        sys.stderr.write("--before must be YYYY-MM-DD\n")
        sys.exit(2)

    repos = fetch_repos(args.limit)
    targets = filter_by_cutoff(repos, cutoff, args.owner)
    print_targets(targets, args.before)
    if args.action == "hide":
        rc = hide_targets(targets, args.apply)
        sys.exit(1 if rc else 0)


if __name__ == "__main__":
    main()
