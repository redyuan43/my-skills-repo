#!/usr/bin/env python3
"""Wrapper around yt-dlp for repeatable Bilibili downloads."""

from __future__ import annotations

import argparse
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse, urlunparse
from urllib.request import HTTPRedirectHandler, Request, build_opener


DEFAULT_OUTPUT_DIR = "./downloads/bilibili"
DEFAULT_UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
)


class NoRedirectHandler(HTTPRedirectHandler):
    """Capture redirect targets without following them into Bilibili's anti-bot flow."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download Bilibili media, subtitles, danmaku, or metadata."
    )
    parser.add_argument("--url", required=True, help="Bilibili or b23.tv URL")
    parser.add_argument(
        "--mode",
        choices=("video", "audio", "subtitles", "metadata"),
        default="video",
        help="What to retrieve",
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help="Directory that will receive all artifacts",
    )
    parser.add_argument(
        "--video-format",
        choices=("best", "mp4", "webm"),
        default="mp4",
        help="Container preference for video mode",
    )
    parser.add_argument(
        "--audio-format",
        choices=("best", "mp3", "m4a", "opus", "wav"),
        default="mp3",
        help="Output format for audio mode",
    )
    parser.add_argument(
        "--subtitle-langs",
        default="all,-live_chat",
        help='Subtitle language selector, for example "zh.*,en.*" or "all,-live_chat"',
    )
    parser.add_argument(
        "--cookies-file",
        help="Path to a user-provided yt-dlp cookies file",
    )
    parser.add_argument(
        "--browser",
        default="chromium",
        help="Browser name for --cookies-from-browser (default: chromium)",
    )
    parser.add_argument(
        "--browser-profile",
        help="Browser profile root directory for --cookies-from-browser",
    )
    parser.add_argument(
        "--no-browser-cookies",
        action="store_true",
        help="Disable automatic browser cookie detection",
    )
    parser.add_argument(
        "--no-resolve-short-url",
        action="store_true",
        help="Do not expand b23.tv short URLs before download",
    )
    parser.add_argument(
        "--write-thumbnail",
        action="store_true",
        help="Save the thumbnail alongside other artifacts",
    )
    parser.add_argument(
        "--restrict-filenames",
        action="store_true",
        help="Use conservative ASCII-safe filenames",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the generated yt-dlp command without executing it",
    )
    return parser.parse_args()


def ensure_dependency(name: str) -> None:
    if shutil.which(name):
        return
    print(f"[ERROR] Required dependency not found in PATH: {name}", file=sys.stderr)
    sys.exit(127)


def normalize_bilibili_url(url: str) -> str:
    parsed = urlparse(url)
    query = parse_qs(parsed.query)
    normalized_query: dict[str, str] = {}
    if "p" in query and query["p"]:
        normalized_query["p"] = query["p"][0]
    return urlunparse(
        (
            parsed.scheme or "https",
            parsed.netloc,
            parsed.path,
            "",
            urlencode(normalized_query),
            "",
        )
    )


def resolve_short_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.netloc not in {"b23.tv", "www.b23.tv"}:
        return url

    opener = build_opener(NoRedirectHandler)
    request = Request(url, headers={"User-Agent": DEFAULT_UA}, method="GET")
    try:
        opener.open(request, timeout=15)
    except HTTPError as exc:
        location = exc.headers.get("Location")
        if exc.code in {301, 302, 303, 307, 308} and location:
            return normalize_bilibili_url(location)
        raise
    except URLError:
        raise

    return url


def detect_browser_profile(explicit: str | None) -> str | None:
    if explicit:
        profile = Path(explicit).expanduser()
        return str(profile.resolve()) if profile.exists() else str(profile)

    candidates = [
        Path("~/.config/chromium").expanduser(),
        Path("~/snap/chromium/common/chromium").expanduser(),
        Path("~/.config/google-chrome").expanduser(),
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate.resolve())
    return None


def build_cookies_args(args: argparse.Namespace) -> list[str]:
    if args.cookies_file:
        return ["--cookies", str(Path(args.cookies_file).expanduser().resolve())]
    if args.no_browser_cookies:
        return []

    profile = detect_browser_profile(args.browser_profile)
    if profile:
        return ["--cookies-from-browser", f"{args.browser}:{profile}"]
    return ["--cookies-from-browser", args.browser]


def build_command(args: argparse.Namespace) -> tuple[list[str], Path, str]:
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_template = "%(title).180B [%(id)s].%(ext)s"

    resolved_url = args.url
    if not args.no_resolve_short_url:
        resolved_url = resolve_short_url(args.url)
    resolved_url = normalize_bilibili_url(resolved_url)

    cmd = [
        "yt-dlp",
        "--newline",
        "--progress",
        "--no-playlist",
        "--paths",
        str(output_dir),
        "--output",
        output_template,
    ]

    if args.restrict_filenames:
        cmd.append("--restrict-filenames")
    cmd.extend(build_cookies_args(args))
    if args.write_thumbnail:
        cmd.append("--write-thumbnail")

    if args.mode == "video":
        cmd.extend(
            [
                "--write-info-json",
                "--write-description",
                "--write-subs",
                "--write-auto-subs",
                "--sub-langs",
                args.subtitle_langs,
                "--embed-metadata",
            ]
        )
        if args.video_format == "mp4":
            cmd.extend(["-f", "bv*+ba/b", "--merge-output-format", "mp4"])
        elif args.video_format == "webm":
            cmd.extend(
                [
                    "-f",
                    "bestvideo[ext=webm]+bestaudio[ext=webm]/best[ext=webm]/bestvideo+bestaudio/best",
                    "--merge-output-format",
                    "webm",
                ]
            )
        else:
            cmd.extend(["-f", "bv*+ba/best"])
        cmd.extend(["--print", "after_move:filepath"])

    elif args.mode == "audio":
        cmd.extend(
            [
                "-x",
                "--audio-quality",
                "0",
                "--write-info-json",
                "--write-description",
                "--print",
                "after_move:filepath",
            ]
        )
        if args.audio_format != "best":
            cmd.extend(["--audio-format", args.audio_format])

    elif args.mode == "subtitles":
        cmd.extend(
            [
                "--skip-download",
                "--write-subs",
                "--write-auto-subs",
                "--sub-langs",
                args.subtitle_langs,
                "--write-info-json",
                "--write-description",
                "--print",
                "filename",
            ]
        )

    elif args.mode == "metadata":
        cmd.extend(
            [
                "--skip-download",
                "--write-info-json",
                "--write-description",
                "--print",
                "filename",
            ]
        )

    cmd.append(resolved_url)
    return cmd, output_dir, resolved_url


def main() -> int:
    args = parse_args()
    ensure_dependency("yt-dlp")

    try:
        cmd, output_dir, resolved_url = build_command(args)
    except (HTTPError, URLError) as exc:
        print(f"[ERROR] Failed to resolve URL: {exc}", file=sys.stderr)
        return 1

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"[INFO] Resolved URL: {resolved_url}")
    print(f"[INFO] Output directory: {output_dir}")
    print(f"[INFO] Command: {shlex.join(cmd)}")

    if args.dry_run:
        return 0

    completed = subprocess.run(cmd, check=False)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
