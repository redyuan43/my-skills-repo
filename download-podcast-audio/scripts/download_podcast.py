#!/usr/bin/env python3
"""Wrapper around yt-dlp for repeatable podcast downloads."""

from __future__ import annotations

import argparse
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download podcast episode audio or metadata with sane defaults."
    )
    parser.add_argument(
        "--url",
        required=True,
        help="Podcast episode page URL or direct audio URL",
    )
    parser.add_argument(
        "--mode",
        choices=("audio", "metadata"),
        default="audio",
        help="What to retrieve",
    )
    parser.add_argument(
        "--output-dir",
        default="./downloads/podcasts",
        help="Directory that will receive all artifacts",
    )
    parser.add_argument(
        "--audio-format",
        choices=("original", "mp3", "m4a", "opus", "wav"),
        default="original",
        help="Audio output format for audio mode",
    )
    parser.add_argument(
        "--cookies",
        help="Path to a user-provided yt-dlp cookies file",
    )
    parser.add_argument(
        "--cookies-from-browser",
        choices=("chrome", "chromium", "firefox", "edge", "safari", "brave"),
        help="Extract cookies directly from a supported browser profile",
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


def build_command(args: argparse.Namespace) -> tuple[list[str], Path]:
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_template = "%(title).180B [%(id)s].%(ext)s"

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
    if args.cookies:
        cmd.extend(["--cookies", str(Path(args.cookies).expanduser().resolve())])
    if args.cookies_from_browser:
        cmd.extend(["--cookies-from-browser", args.cookies_from_browser])
    if args.write_thumbnail:
        cmd.append("--write-thumbnail")

    if args.mode == "audio":
        cmd.extend(["--write-info-json", "--write-description", "--print", "after_move:filepath"])
        if args.audio_format != "original":
            cmd.extend(["-x", "--audio-quality", "0", "--audio-format", args.audio_format])
    else:
        cmd.extend(["--skip-download", "--write-info-json", "--write-description", "--print", "filename"])

    cmd.append(args.url)
    return cmd, output_dir


def main() -> int:
    args = parse_args()
    ensure_dependency("yt-dlp")

    cmd, output_dir = build_command(args)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"[INFO] Output directory: {output_dir}")
    print(f"[INFO] Command: {shlex.join(cmd)}")

    if args.dry_run:
        return 0

    completed = subprocess.run(cmd, check=False)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
