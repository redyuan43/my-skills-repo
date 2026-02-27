#!/usr/bin/env python3
import argparse
import subprocess
import sys
import time
from typing import Dict, List, Tuple


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Monitor selected processes and alert on failure.")
    p.add_argument("--names", default="", help="Comma-separated process names or keywords.")
    p.add_argument("--pids", default="", help="Comma-separated exact PIDs.")
    p.add_argument("--interval", type=int, default=5, help="Polling interval in seconds.")
    p.add_argument("--min-cpu", type=float, default=0.5, help="Low CPU threshold percent.")
    p.add_argument(
        "--grace-checks",
        type=int,
        default=3,
        help="Consecutive low-CPU checks before alert.",
    )
    return p.parse_args()


def parse_csv_list(value: str) -> List[str]:
    return [x.strip() for x in value.split(",") if x.strip()]


def snapshot_ps() -> List[Dict[str, str]]:
    cmd = ["ps", "-eo", "pid=,pcpu=,comm=,args="]
    out = subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
    rows: List[Dict[str, str]] = []
    for raw in out.splitlines():
        line = raw.strip()
        if not line:
            continue
        parts = line.split(None, 3)
        if len(parts) < 3:
            continue
        rows.append(
            {
                "pid": parts[0],
                "cpu": parts[1],
                "name": parts[2],
                "cmdline": parts[3] if len(parts) > 3 else parts[2],
            }
        )
    return rows


def find_matches(rows: List[Dict[str, str]], names: List[str], pids: List[str]) -> Tuple[Dict[str, List[Dict[str, str]]], Dict[str, List[Dict[str, str]]]]:
    by_pid: Dict[str, List[Dict[str, str]]] = {pid: [] for pid in pids}
    by_name: Dict[str, List[Dict[str, str]]] = {n: [] for n in names}

    lower_names = {n: n.lower() for n in names}

    for row in rows:
        if row["pid"] in by_pid:
            by_pid[row["pid"]].append(row)

        name_l = row["name"].lower()
        cmd_l = row["cmdline"].lower()
        for original, token in lower_names.items():
            if token in name_l or token in cmd_l:
                by_name[original].append(row)

    return by_pid, by_name


def bell_alert(msg: str) -> None:
    print(f"\aALERT: {msg}")


def main() -> int:
    args = parse_args()
    names = parse_csv_list(args.names)
    pids = parse_csv_list(args.pids)

    if not names and not pids:
        print("At least one of --names or --pids is required.", file=sys.stderr)
        return 2

    low_cpu_streak: Dict[str, int] = {f"pid:{pid}": 0 for pid in pids}
    low_cpu_streak.update({f"name:{name}": 0 for name in names})

    print(
        f"Watching names={names or '[]'} pids={pids or '[]'} interval={args.interval}s min_cpu={args.min_cpu}% grace_checks={args.grace_checks}"
    )

    while True:
        try:
            rows = snapshot_ps()
        except subprocess.CalledProcessError as e:
            bell_alert(f"failed to read process list: {e}")
            time.sleep(args.interval)
            continue

        by_pid, by_name = find_matches(rows, names, pids)

        # PID checks
        for pid in pids:
            key = f"pid:{pid}"
            matches = by_pid[pid]
            if not matches:
                bell_alert(f"PID {pid} is not running")
                continue

            max_cpu = max(float(m["cpu"]) for m in matches)
            if max_cpu < args.min_cpu:
                low_cpu_streak[key] += 1
                if low_cpu_streak[key] >= args.grace_checks:
                    bell_alert(
                        f"PID {pid} stayed below {args.min_cpu}% CPU for {low_cpu_streak[key]} checks"
                    )
            else:
                low_cpu_streak[key] = 0

        # Name checks
        for name in names:
            key = f"name:{name}"
            matches = by_name[name]
            if not matches:
                bell_alert(f"process '{name}' is not running")
                continue

            max_cpu = max(float(m["cpu"]) for m in matches)
            if max_cpu < args.min_cpu:
                low_cpu_streak[key] += 1
                if low_cpu_streak[key] >= args.grace_checks:
                    bell_alert(
                        f"process '{name}' stayed below {args.min_cpu}% CPU for {low_cpu_streak[key]} checks"
                    )
            else:
                low_cpu_streak[key] = 0

        status_items = []
        for pid in pids:
            m = by_pid[pid]
            cpu = f"{max(float(x['cpu']) for x in m):.1f}%" if m else "DOWN"
            status_items.append(f"pid:{pid}={cpu}")
        for name in names:
            m = by_name[name]
            cpu = f"{max(float(x['cpu']) for x in m):.1f}%" if m else "DOWN"
            status_items.append(f"name:{name}={cpu}")

        print(time.strftime("%Y-%m-%d %H:%M:%S"), "|", " ; ".join(status_items))
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
