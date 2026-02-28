#!/usr/bin/env python3
"""Wrapper around yt-dlp with repeatable presets for agent workflows."""

from __future__ import annotations

import argparse
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download YouTube media, subtitles, or metadata with sane defaults."
    )
    parser.add_argument("--url", required=True, help="YouTube watch, shorts, or playlist URL")
    parser.add_argument(
        "--mode",
        choices=("video", "audio", "subtitles", "metadata"),
        default="video",
        help="What to retrieve",
    )
    parser.add_argument(
        "--output-dir",
        default="./downloads/youtube",
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
        default="all",
        help='Subtitle language selector, for example "en.*,zh.*" or "all"',
    )
    parser.add_argument(
        "--playlist",
        action="store_true",
        help="Allow playlist downloads. Default behavior is single-item only.",
    )
    parser.add_argument(
        "--cookies",
        help="Path to a user-provided yt-dlp cookies file for gated content",
    )
    parser.add_argument(
        "--write-thumbnail",
        action="store_true",
        help="Save the thumbnail alongside other artifacts",
    )
    parser.add_argument(
        "--write-description",
        action="store_true",
        help="Save the video description as text",
    )
    parser.add_argument(
        "--write-info-json",
        action="store_true",
        help="Save yt-dlp metadata as JSON",
    )
    parser.add_argument(
        "--embed-subs",
        action="store_true",
        help="Embed subtitles into the video output when possible",
    )
    parser.add_argument(
        "--auto-subs",
        action="store_true",
        help="Also fetch automatically generated subtitles when available",
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
        "--paths",
        str(output_dir),
        "--output",
        output_template,
    ]

    if args.restrict_filenames:
        cmd.append("--restrict-filenames")
    if args.playlist:
        cmd.append("--yes-playlist")
    else:
        cmd.append("--no-playlist")
    if args.cookies:
        cmd.extend(["--cookies", str(Path(args.cookies).expanduser().resolve())])
    if args.write_info_json:
        cmd.append("--write-info-json")
    if args.write_description:
        cmd.append("--write-description")
    if args.write_thumbnail:
        cmd.append("--write-thumbnail")

    if args.mode == "video":
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

        if args.embed_subs:
            cmd.extend(["--write-subs", "--embed-subs"])
            if args.auto_subs:
                cmd.append("--write-auto-subs")
            cmd.extend(["--sub-langs", args.subtitle_langs])
        cmd.extend(["--print", "after_move:filepath"])

    elif args.mode == "audio":
        cmd.extend(["-x", "--audio-quality", "0", "--print", "after_move:filepath"])
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
            ]
        )
        cmd.extend(["--print", "filename"])

    elif args.mode == "metadata":
        cmd.append("--skip-download")
        if not (args.write_info_json or args.write_description or args.write_thumbnail):
            cmd.extend(["--write-info-json", "--write-description"])
        cmd.extend(["--print", "filename"])

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
