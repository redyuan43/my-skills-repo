#!/usr/bin/env python3
"""Download Pinterest Pin media with yt-dlp and stable local defaults."""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse
from urllib.request import Request, urlopen


BAD_PROXY_KEYS = ("ftp_proxy", "FTP_PROXY", "ALL_PROXY", "all_proxy")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download the highest available media from a Pinterest Pin URL."
    )
    parser.add_argument("--url", required=True, help="Pinterest Pin URL")
    parser.add_argument(
        "--mode",
        choices=("auto", "video", "photo", "metadata"),
        default="auto",
        help="What to retrieve. auto probes the Pin and chooses video or photo.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(Path.home() / "Desktop" / "Pinterest Downloads"),
        help="Directory that will receive downloaded artifacts.",
    )
    parser.add_argument(
        "--cookies",
        help="Path to a user-provided yt-dlp cookies file for gated content.",
    )
    parser.add_argument(
        "--cookies-from-browser",
        choices=("chrome", "chromium", "firefox", "edge", "safari", "brave"),
        help="Extract cookies from a local browser profile.",
    )
    parser.add_argument(
        "--write-info-json",
        action="store_true",
        help="Save yt-dlp metadata JSON next to the media.",
    )
    parser.add_argument(
        "--restrict-filenames",
        action="store_true",
        help="Use conservative ASCII-safe filenames.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print generated commands without downloading.",
    )
    return parser.parse_args()


def ensure_dependency(name: str) -> None:
    if shutil.which(name):
        return
    print(f"[ERROR] Required dependency not found in PATH: {name}", file=sys.stderr)
    sys.exit(127)


def yt_dlp_env() -> dict[str, str]:
    env = os.environ.copy()
    for key in BAD_PROXY_KEYS:
        env.pop(key, None)
    return env


def base_command(args: argparse.Namespace, output_dir: Path) -> list[str]:
    cmd = [
        "yt-dlp",
        "--newline",
        "--progress",
        "--no-playlist",
        "--paths",
        str(output_dir),
        "--output",
        "%(title).180B [%(id)s].%(ext)s",
    ]
    if args.restrict_filenames:
        cmd.append("--restrict-filenames")
    if args.cookies:
        cmd.extend(["--cookies", str(Path(args.cookies).expanduser().resolve())])
    if args.cookies_from_browser:
        cmd.extend(["--cookies-from-browser", args.cookies_from_browser])
    if args.write_info_json:
        cmd.append("--write-info-json")
    return cmd


def probe_pin(args: argparse.Namespace) -> dict[str, Any]:
    cmd = ["yt-dlp", "--no-playlist", "-J"]
    if args.cookies:
        cmd.extend(["--cookies", str(Path(args.cookies).expanduser().resolve())])
    if args.cookies_from_browser:
        cmd.extend(["--cookies-from-browser", args.cookies_from_browser])
    cmd.append(args.url)
    print(f"[INFO] Probe command: {shlex.join(cmd)}")
    completed = subprocess.run(
        cmd,
        check=False,
        capture_output=True,
        text=True,
        env=yt_dlp_env(),
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip())
    return json.loads(completed.stdout)


def has_video_format(info: dict[str, Any]) -> bool:
    for item in info.get("formats") or []:
        vcodec = item.get("vcodec")
        if vcodec and vcodec != "none":
            return True
    ext = str(info.get("ext") or "").lower()
    return ext in {"mp4", "webm", "mov", "m3u8"}


def detect_mode(args: argparse.Namespace) -> str:
    if args.mode != "auto":
        return args.mode
    try:
        info = probe_pin(args)
    except RuntimeError as exc:
        if "No video formats found" in str(exc):
            print("[INFO] yt-dlp found no video formats; falling back to photo mode")
            return "photo"
        print(str(exc), file=sys.stderr)
        sys.exit(1)
    title = info.get("title") or "Pinterest Pin"
    duration = info.get("duration")
    detected = "video" if has_video_format(info) else "photo"
    duration_text = f", duration={duration}s" if duration else ""
    print(f"[INFO] Detected {detected}: {title}{duration_text}")
    return detected


def fetch_text(url: str) -> str:
    request = Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"
            )
        },
    )
    with urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", errors="replace")


def first_meta_content(page: str, names: tuple[str, ...]) -> str | None:
    for name in names:
        patterns = [
            rf'<meta[^>]+(?:property|name)=["\']{re.escape(name)}["\'][^>]+content=["\']([^"\']+)["\']',
            rf'<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']{re.escape(name)}["\']',
        ]
        for pattern in patterns:
            match = re.search(pattern, page, flags=re.IGNORECASE)
            if match:
                return html.unescape(match.group(1))
    return None


def pin_id_from_url(url: str) -> str:
    match = re.search(r"/pin/(\d+)", url)
    return match.group(1) if match else "pinterest-pin"


def safe_stem(value: str) -> str:
    value = unquote(value).strip() or "Pinterest Pin"
    value = re.sub(r"\s+", " ", value)
    value = re.sub(r'[\\/:*?"<>|]+', "_", value)
    return value[:180].strip(" ._") or "Pinterest Pin"


def image_candidates(image_url: str) -> list[str]:
    candidates = []
    parsed = urlparse(image_url)
    if "pinimg.com" in parsed.netloc:
        upgraded = re.sub(r"/(?:\d+x|originals|736x|564x|474x|236x)/", "/originals/", image_url, count=1)
        candidates.append(upgraded)
    candidates.append(image_url)

    seen = set()
    ordered = []
    for candidate in candidates:
        if candidate not in seen:
            seen.add(candidate)
            ordered.append(candidate)
    return ordered


def download_photo(args: argparse.Namespace, output_dir: Path) -> int:
    print(f"[INFO] Fetching Pinterest page for image metadata: {args.url}")
    try:
        page = fetch_text(args.url)
    except Exception as exc:
        print(f"[ERROR] Could not fetch Pinterest page: {exc}", file=sys.stderr)
        return 1

    image_url = first_meta_content(page, ("og:image", "twitter:image"))
    if not image_url:
        print("[ERROR] Could not find og:image or twitter:image in the Pin page.", file=sys.stderr)
        return 1

    title = first_meta_content(page, ("og:title", "twitter:title")) or "Pinterest Pin"
    pin_id = pin_id_from_url(args.url)

    for candidate in image_candidates(image_url):
        parsed = urlparse(candidate)
        suffix = Path(parsed.path).suffix or ".jpg"
        output_path = output_dir / f"{safe_stem(title)} [{pin_id}]{suffix}"
        request = Request(candidate, headers={"User-Agent": "Mozilla/5.0"})
        print(f"[INFO] Image candidate: {candidate}")
        try:
            with urlopen(request, timeout=30) as response:
                data = response.read()
            if len(data) < 1024:
                raise RuntimeError(f"Downloaded image is unexpectedly small: {len(data)} bytes")
            output_path.write_bytes(data)
            print(str(output_path))
            return 0
        except Exception as exc:
            print(f"[WARN] Image candidate failed: {exc}", file=sys.stderr)

    print("[ERROR] All image candidates failed.", file=sys.stderr)
    return 1


def build_download_command(args: argparse.Namespace, mode: str, output_dir: Path) -> list[str]:
    cmd = base_command(args, output_dir)
    if mode == "video":
        cmd.extend(["-f", "bv*+ba/best", "--merge-output-format", "mp4"])
        cmd.extend(["--print", "after_move:filepath"])
    elif mode == "photo":
        cmd.extend(["--print", "after_move:filepath"])
    elif mode == "metadata":
        cmd.extend(["--skip-download", "--write-info-json", "--print", "filename"])
    else:
        raise ValueError(f"Unsupported mode: {mode}")
    cmd.append(args.url)
    return cmd


def main() -> int:
    args = parse_args()
    if "pinterest." not in args.url.lower() or "/pin/" not in args.url.lower():
        print("[ERROR] Expected a Pinterest Pin URL containing /pin/.", file=sys.stderr)
        return 2

    ensure_dependency("yt-dlp")
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    mode = detect_mode(args)
    if mode == "photo":
        return download_photo(args, output_dir)

    cmd = build_download_command(args, mode, output_dir)
    print(f"[INFO] Output directory: {output_dir}")
    print(f"[INFO] Download command: {shlex.join(cmd)}")

    if args.dry_run:
        return 0

    completed = subprocess.run(cmd, check=False, env=yt_dlp_env())
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
