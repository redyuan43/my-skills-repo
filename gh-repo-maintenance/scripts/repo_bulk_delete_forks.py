#!/usr/bin/env python3
"""
Batch delete fork repositories using gh CLI.

Default mode is dry-run. Use --apply to actually delete.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True)


def parse_ymd(s: str) -> datetime:
    try:
        return datetime.strptime(s, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid date: {s} (expected YYYY-MM-DD)")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--owner", default=None, help="Owner filter (default: current gh account repos)")
    p.add_argument("--limit", type=int, default=300, help="Max repos to fetch (default: 300)")
    p.add_argument("--created-before", type=parse_ymd, required=True, help="Match forks created before YYYY-MM-DD")
    p.add_argument("--updated-before", type=parse_ymd, default=None, help="Optional stale filter by updatedAt")
    p.add_argument("--apply", action="store_true", help="Actually delete repos (default: dry-run)")
    return p.parse_args()


def fetch_repos(limit: int) -> list[dict]:
    fields = "name,nameWithOwner,isFork,isPrivate,visibility,createdAt,updatedAt"
    cp = run(["gh", "repo", "list", "--limit", str(limit), "--json", fields])
    if cp.returncode != 0:
        sys.stderr.write(cp.stderr or cp.stdout or "gh repo list failed\n")
        sys.exit(cp.returncode)
    return json.loads(cp.stdout)


def to_dt(iso: str) -> datetime:
    return datetime.fromisoformat(iso.replace("Z", "+00:00"))


def main() -> None:
    args = parse_args()
    repos = fetch_repos(args.limit)
    targets: list[dict] = []

    for r in repos:
        if not r["isFork"]:
            continue
        if args.owner and not r["nameWithOwner"].lower().startswith(args.owner.lower() + "/"):
            continue
        if to_dt(r["createdAt"]) >= args.created_before:
            continue
        if args.updated_before and to_dt(r["updatedAt"]) >= args.updated_before:
            continue
        targets.append(r)

    targets.sort(key=lambda r: (r["createdAt"], r["nameWithOwner"]))

    print(
        "FILTER "
        f"forks createdAt < {args.created_before.strftime('%Y-%m-%d')}T00:00:00Z"
        + (
            f", updatedAt < {args.updated_before.strftime('%Y-%m-%d')}T00:00:00Z"
            if args.updated_before
            else ""
        )
    )
    print(f"COUNT {len(targets)}")
    for r in targets:
        print(
            f"{r['createdAt'][:10]} | {r['updatedAt'][:10]} | "
            f"{r['visibility']:<7} | {r['nameWithOwner']}"
        )

    if not args.apply:
        for r in targets:
            print(f"WOULD_DELETE {r['nameWithOwner']}")
        return

    failures = 0
    for r in targets:
        repo = r["nameWithOwner"]
        cp = run(["gh", "repo", "delete", repo, "--yes"])
        if cp.returncode == 0:
            print(f"DELETE_OK {repo}")
            continue
        msg = (cp.stderr or cp.stdout or "").strip().replace("\n", " ")
        print(f"DELETE_FAIL {repo} :: {msg}")
        failures += 1

    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
