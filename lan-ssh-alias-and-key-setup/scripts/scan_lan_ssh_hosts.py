#!/usr/bin/env python3
from __future__ import annotations

import argparse
import concurrent.futures
import json
import socket
import subprocess
import sys
from dataclasses import asdict, dataclass

import paramiko


@dataclass
class HostResult:
    ip: str
    status: str
    hostname: str = ""
    username: str = ""


def run_fping(subnet: str) -> list[str]:
    proc = subprocess.run(
        ["fping", "-a", "-q", "-g", subnet],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def port22_open(ip: str, timeout: float) -> bool:
    sock = socket.socket()
    sock.settimeout(timeout)
    try:
        sock.connect((ip, 22))
        return True
    except Exception:
        return False
    finally:
        sock.close()


def try_login(ip: str, username: str, password: str, timeout: float) -> HostResult:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(
            ip,
            port=22,
            username=username,
            password=password,
            timeout=timeout,
            banner_timeout=timeout,
            auth_timeout=timeout,
            allow_agent=False,
            look_for_keys=False,
        )
        _, stdout, _ = client.exec_command("hostname", timeout=timeout)
        hostname = stdout.read().decode(errors="ignore").strip()
        return HostResult(ip=ip, status="ok", hostname=hostname, username=username)
    except paramiko.AuthenticationException:
        return HostResult(ip=ip, status="auth_fail", username=username)
    except Exception as exc:
        return HostResult(ip=ip, status=type(exc).__name__, username=username)
    finally:
        try:
            client.close()
        except Exception:
            pass


def group_by_hostname(results: list[HostResult]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    for result in results:
        if result.status != "ok":
            continue
        key = result.hostname or "(unknown-hostname)"
        groups.setdefault(key, []).append(result.ip)
    return groups


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scan a subnet for SSH hosts and test one shared credential."
    )
    parser.add_argument("--subnet", required=True, help="CIDR, for example 192.168.100.0/24")
    parser.add_argument("--username", required=True, help="SSH username to test")
    parser.add_argument("--password", required=True, help="SSH password to test")
    parser.add_argument("--connect-timeout", type=float, default=1.0)
    parser.add_argument("--auth-timeout", type=float, default=2.0)
    parser.add_argument("--json", action="store_true", help="Print JSON output")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        live_ips = run_fping(args.subnet)
    except FileNotFoundError:
        print("fping not found in PATH", file=sys.stderr)
        return 2

    with concurrent.futures.ThreadPoolExecutor(max_workers=64) as executor:
        open_map = executor.map(
            lambda ip: port22_open(ip, args.connect_timeout),
            live_ips,
        )
        ssh_ips = [ip for ip, is_open in zip(live_ips, open_map) if is_open]

    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as executor:
        results = list(
            executor.map(
                lambda ip: try_login(ip, args.username, args.password, args.auth_timeout),
                ssh_ips,
            )
        )

    grouped = group_by_hostname(results)
    payload = {
        "subnet": args.subnet,
        "live_count": len(live_ips),
        "ssh_open_count": len(ssh_ips),
        "ok_count": sum(1 for result in results if result.status == "ok"),
        "grouped_ok_hosts": grouped,
        "results": [asdict(result) for result in sorted(results, key=lambda item: item.ip)],
    }

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0

    print(f"subnet: {args.subnet}")
    print(f"live_count: {payload['live_count']}")
    print(f"ssh_open_count: {payload['ssh_open_count']}")
    print(f"ok_count: {payload['ok_count']}")
    print("")
    print("ok_hosts_by_hostname:")
    for hostname, ips in sorted(grouped.items()):
        print(f"- {hostname}: {', '.join(sorted(ips))}")
    print("")
    print("details:")
    for result in sorted(results, key=lambda item: item.ip):
        suffix = f" hostname={result.hostname}" if result.hostname else ""
        print(f"- {result.ip}: {result.status}{suffix}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
