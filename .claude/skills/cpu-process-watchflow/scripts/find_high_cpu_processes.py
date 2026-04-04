#!/usr/bin/env python3
import argparse
import csv
import subprocess
import sys
from typing import Dict, List


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="List current high-CPU processes.")
    p.add_argument("--threshold", type=float, default=8.0, help="Minimum CPU percent.")
    p.add_argument("--top", type=int, default=20, help="Maximum rows to print.")
    return p.parse_args()


def list_with_ps() -> List[Dict[str, str]]:
    cmd = ["ps", "-eo", "pid=,pcpu=,comm=,args=", "--sort=-pcpu"]
    out = subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
    rows: List[Dict[str, str]] = []
    for raw in out.splitlines():
        line = raw.strip()
        if not line:
            continue
        parts = line.split(None, 3)
        if len(parts) < 3:
            continue
        pid = parts[0]
        cpu = parts[1]
        name = parts[2]
        cmdline = parts[3] if len(parts) > 3 else name
        rows.append({"pid": pid, "cpu": cpu, "name": name, "cmdline": cmdline})
    return rows


def main() -> int:
    args = parse_args()
    rows = list_with_ps()

    filtered = [r for r in rows if float(r["cpu"]) >= args.threshold][: args.top]

    if not filtered:
        print("No processes above threshold.")
        return 0

    writer = csv.writer(sys.stdout)
    writer.writerow(["PID", "CPU%", "NAME", "CMDLINE"])
    for r in filtered:
        writer.writerow([r["pid"], r["cpu"], r["name"], r["cmdline"]])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
