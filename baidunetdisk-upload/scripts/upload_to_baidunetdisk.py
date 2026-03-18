#!/usr/bin/env python3
"""Upload local files to Baidu Netdisk via the existing CLI-Anything harness."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_HARNESS_ROOT = Path("/home/ivan/github/CLI-Anything/baidunetdisk/agent-harness")


def _load_backend(harness_root: Path):
    if not harness_root.exists():
        raise FileNotFoundError(f"Harness root not found: {harness_root}")
    sys.path.insert(0, str(harness_root))
    from cli_anything.baidunetdisk.utils import baidunetdisk_backend as backend  # noqa: PLC0415

    return backend


def _normalize_remote_folder(raw: str | None) -> str:
    if not raw:
        return f"baidunetdisk-upload-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    folder = raw.strip().strip("/")
    if not folder or folder in {".", ".."} or "/" in folder:
        raise ValueError("remote folder must be a single root-level folder name")
    return folder


def _copy_item(src: Path, dest: Path) -> None:
    if src.is_dir():
        shutil.copytree(src, dest)
        return
    shutil.copy2(src, dest)


def _build_stage_dir(selected_paths: list[str], remote_folder: str) -> dict[str, Any]:
    stage_root = Path(tempfile.mkdtemp(prefix="baidunetdisk-upload-stage-"))
    upload_root = stage_root / remote_folder
    upload_root.mkdir(parents=True, exist_ok=True)

    copied_items: list[str] = []
    seen_names: set[str] = set()
    for raw in selected_paths:
        src = Path(raw)
        name = src.name
        if name in seen_names:
            raise ValueError(f"duplicate basename detected: {name}")
        seen_names.add(name)
        dest = upload_root / name
        _copy_item(src, dest)
        copied_items.append(str(dest))

    return {
        "stage_root": str(stage_root),
        "upload_root": str(upload_root),
        "copied_items": copied_items,
    }


def _plain_print(payload: dict[str, Any]) -> None:
    print(f"remote_path: {payload['remote_path']}")
    print("selected_paths:")
    for item in payload["selected_paths"]:
        print(f"  - {item}")
    print(f"upload_root: {payload['upload_root']}")
    enqueue = payload["enqueue"]
    print(f"launched: {enqueue.get('launched')}")
    if payload.get("remote_listing"):
        print(f"remote_count: {payload['remote_listing'].get('count')}")
        for item in payload["remote_listing"].get("items", []):
            print(f"  - {item.get('server_path')}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("queries", nargs="+", help="Exact local paths or rough local search queries")
    parser.add_argument("--remote-folder", default=None, help="Root-level remote folder name to create")
    parser.add_argument("--harness-root", default=str(DEFAULT_HARNESS_ROOT), help="Path to the existing Baidu Netdisk harness")
    parser.add_argument("--wait-timeout", type=float, default=20.0, help="Seconds to wait for upload confirmation")
    parser.add_argument("--keep-temp", action="store_true", help="Keep the temporary staging directory")
    parser.add_argument("--dry-run", action="store_true", help="Prepare and resolve without real upload")
    parser.add_argument(
        "--confirm-live-upload",
        action="store_true",
        help="Required for real upload; without it the script refuses to call the desktop client",
    )
    parser.add_argument("--json", action="store_true", help="Print JSON output")
    args = parser.parse_args()

    if not args.dry_run and not args.confirm_live_upload:
        raise SystemExit("Refusing live upload without --confirm-live-upload")

    harness_root = Path(os.path.expanduser(args.harness_root)).resolve()
    backend = _load_backend(harness_root)

    resolutions = [backend.resolve_local_path(query) for query in args.queries]
    missing = [item for item in resolutions if item["status"] == "missing"]
    ambiguous = [item for item in resolutions if item["status"] == "ambiguous"]
    if missing:
        missing_queries = ", ".join(item["query"] for item in missing)
        raise FileNotFoundError(f"unresolved queries: {missing_queries}")
    if ambiguous:
        details = "; ".join(f"{item['query']} -> {item['matches'][:5]}" for item in ambiguous)
        raise RuntimeError(f"ambiguous queries: {details}")

    selected_paths = [item["selected"] for item in resolutions if item["selected"]]
    remote_folder = _normalize_remote_folder(args.remote_folder)
    staged = _build_stage_dir(selected_paths, remote_folder)
    remote_path = f"/{remote_folder}"

    payload: dict[str, Any] = {
        "skill": "baidunetdisk-upload",
        "dry_run": args.dry_run,
        "harness_root": str(harness_root),
        "queries": list(args.queries),
        "resolutions": resolutions,
        "selected_paths": selected_paths,
        "remote_folder": remote_folder,
        "remote_path": remote_path,
        "stage_root": staged["stage_root"],
        "upload_root": staged["upload_root"],
        "copied_items": staged["copied_items"],
    }

    try:
        enqueue = backend.enqueue_upload_via_native(
            [staged["upload_root"]],
            wait_timeout=args.wait_timeout,
            dry_run=args.dry_run,
        )
        payload["enqueue"] = enqueue

        if not args.dry_run:
            payload["history"] = backend.list_upload_history(
                local_paths=[staged["upload_root"]],
                limit=max(20, len(selected_paths) + 5),
            )
            payload["remote_listing"] = backend.list_remote_dir(
                remote_path,
                limit=max(20, len(selected_paths) + 5),
            )
    finally:
        should_cleanup = not args.keep_temp and not args.dry_run
        if should_cleanup and os.path.isdir(staged["stage_root"]):
            shutil.rmtree(staged["stage_root"], ignore_errors=True)
            payload["stage_root_removed"] = True
        else:
            payload["stage_root_removed"] = False

    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False, default=str))
    else:
        _plain_print(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
