#!/usr/bin/env python3
"""Search image content in one Baidu Netdisk scope through the CLI-Anything harness."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path
from typing import Any


DEFAULT_HARNESS_ROOT = Path("/home/ivan/github/CLI-Anything/baidunetdisk/agent-harness")


def _build_command(args: argparse.Namespace) -> tuple[Path, list[str]]:
    harness_root = Path(os.path.expanduser(args.harness_root)).resolve()
    command = [
        "python3",
        "-m",
        "cli_anything.baidunetdisk.baidunetdisk_cli",
        "--json",
        "remote",
        "image",
        "search",
        args.query,
        "--path",
        args.path,
        "--top-k",
        str(args.top_k),
        "--fetch-level",
        args.fetch_level,
        "--limit-per-dir",
        str(args.limit_per_dir),
    ]
    if args.cache_root:
        command.extend(["--cache-root", args.cache_root])
    if args.zbox_repo:
        command.extend(["--zbox-repo", args.zbox_repo])
    if not args.sync_cache:
        command.append("--no-sync-cache")
    if not args.recursive:
        command.append("--no-recursive")
    if not args.image_caption:
        command.append("--no-image-caption")
    if not args.image_ocr:
        command.append("--no-image-ocr")
    if args.allow_cloud_vision:
        command.append("--allow-cloud-vision")
    return harness_root, command


def _plain_print(payload: dict[str, Any]) -> None:
    print(f"query: {payload['query']}")
    print(f"remote_path: {payload['remote_path']}")
    print(f"hit_count: {payload['hit_count']}")
    print(f"local_only: {payload['local_only']}")
    print("hits:")
    for item in payload.get("hits", []):
        print(f"  - {item.get('remote_path')} [{item.get('match_source')}] score={item.get('score')}")
        snippet = item.get("snippet")
        if snippet:
            print(f"    snippet: {snippet}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query", help="OCR/caption keyword to search")
    parser.add_argument("--path", default="/", help="Remote Baidu Netdisk scope")
    parser.add_argument("--harness-root", default=str(DEFAULT_HARNESS_ROOT), help="Path to the Baidu Netdisk harness")
    parser.add_argument("--cache-root", default=None, help="Override local image cache root")
    parser.add_argument("--zbox-repo", default="/home/ivan/github/ZBox", help="Local ZBox repository path")
    parser.add_argument("--top-k", type=int, default=5, help="Maximum number of hits")
    parser.add_argument("--fetch-level", choices=["thumbnail", "medium"], default="medium")
    parser.add_argument("--limit-per-dir", type=int, default=1000)
    parser.add_argument("--no-sync-cache", dest="sync_cache", action="store_false")
    parser.add_argument("--no-recursive", dest="recursive", action="store_false")
    parser.add_argument("--no-image-caption", dest="image_caption", action="store_false")
    parser.add_argument("--no-image-ocr", dest="image_ocr", action="store_false")
    parser.add_argument(
        "--allow-cloud-vision",
        action="store_true",
        help="Allow the harness to keep ZBox cloud vision settings instead of forcing local-only mode",
    )
    parser.add_argument("--json", action="store_true")
    parser.set_defaults(sync_cache=True, recursive=True, image_caption=True, image_ocr=True)
    args = parser.parse_args()

    harness_root, command = _build_command(args)
    completed = subprocess.run(command, cwd=harness_root, check=True, capture_output=True, text=True)
    payload = json.loads(completed.stdout)

    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        _plain_print(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
