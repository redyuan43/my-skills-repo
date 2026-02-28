#!/usr/bin/env python3
"""Inspect a video file and generate structured artifacts for downstream analysis."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any


TEXT_SUBTITLE_EXTENSIONS = {
    "ass": "ass",
    "mov_text": "srt",
    "srt": "srt",
    "ssa": "ass",
    "subrip": "srt",
    "text": "srt",
    "webvtt": "vtt",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze a local video file with ffprobe and ffmpeg."
    )
    parser.add_argument("--input", required=True, help="Path to the video file")
    parser.add_argument(
        "--output-dir",
        help="Directory for generated artifacts. Defaults to ./video-analysis/<video-name>",
    )
    parser.add_argument(
        "--mode",
        choices=("summary", "transcript", "technical"),
        default="summary",
        help="Artifact preset",
    )
    parser.add_argument(
        "--frame-interval",
        type=float,
        default=30.0,
        help="Seconds between sampled frames in summary mode",
    )
    parser.add_argument(
        "--max-frames",
        type=int,
        default=12,
        help="Maximum number of sampled frames",
    )
    parser.add_argument(
        "--transcribe",
        choices=("auto", "off"),
        default="auto",
        help="Run local Whisper when available",
    )
    parser.add_argument(
        "--language",
        help="Optional language hint for Whisper, for example en or zh",
    )
    parser.add_argument(
        "--whisper-model",
        default="base",
        help="Whisper model name when transcription is enabled",
    )
    return parser.parse_args()


def ensure_dependency(name: str) -> None:
    if shutil.which(name):
        return
    print(f"[ERROR] Required dependency not found in PATH: {name}", file=sys.stderr)
    sys.exit(127)


def run_command(cmd: list[str], capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        check=True,
        text=True,
        capture_output=capture,
    )


def run_ffprobe(input_path: Path) -> dict[str, Any]:
    result = run_command(
        [
            "ffprobe",
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_format",
            "-show_streams",
            str(input_path),
        ],
        capture=True,
    )
    return json.loads(result.stdout)


def format_seconds(value: str | int | float | None) -> str:
    if value in (None, "", "N/A"):
        return "unknown"
    seconds = float(value)
    hours, remainder = divmod(int(seconds), 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def parse_frame_rate(value: str | None) -> str:
    if not value or value == "0/0":
        return "unknown"
    try:
        return f"{float(Fraction(value)):.3f} fps"
    except (ValueError, ZeroDivisionError):
        return value


def find_sidecar_subtitles(input_path: Path) -> list[Path]:
    matches: list[Path] = []
    for extension in ("srt", "vtt", "ass", "ssa"):
        matches.extend(sorted(input_path.parent.glob(f"{input_path.stem}*.{extension}")))
    return matches


def extract_frames(
    input_path: Path,
    output_dir: Path,
    frame_interval: float,
    max_frames: int,
) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    target = output_dir / "frame_%03d.jpg"
    run_command(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(input_path),
            "-vf",
            f"fps=1/{frame_interval}",
            "-frames:v",
            str(max_frames),
            "-q:v",
            "2",
            str(target),
        ]
    )
    frames = sorted(output_dir.glob("frame_*.jpg"))
    if frames:
        return frames

    fallback_target = output_dir / "frame_001.jpg"
    run_command(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(input_path),
            "-frames:v",
            "1",
            "-q:v",
            "2",
            str(fallback_target),
        ]
    )
    return sorted(output_dir.glob("frame_*.jpg"))


def extract_audio(input_path: Path, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    target = output_dir / "audio.wav"
    run_command(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(input_path),
            "-vn",
            "-ac",
            "1",
            "-ar",
            "16000",
            str(target),
        ]
    )
    return target


def extract_subtitles(
    input_path: Path,
    streams: list[dict[str, Any]],
    output_dir: Path,
) -> tuple[list[Path], list[dict[str, Any]]]:
    output_dir.mkdir(parents=True, exist_ok=True)
    created: list[Path] = []
    skipped: list[dict[str, Any]] = []

    for stream in streams:
        if stream.get("codec_type") != "subtitle":
            continue
        codec_name = stream.get("codec_name", "")
        extension = TEXT_SUBTITLE_EXTENSIONS.get(codec_name)
        language = stream.get("tags", {}).get("language", "und")
        stream_index = stream.get("index")

        if extension is None:
            skipped.append(
                {
                    "index": stream_index,
                    "codec_name": codec_name,
                    "reason": "unsupported subtitle codec for text extraction",
                }
            )
            continue

        target = output_dir / f"subtitle_{stream_index}_{language}.{extension}"
        try:
            run_command(
                [
                    "ffmpeg",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-y",
                    "-i",
                    str(input_path),
                    "-map",
                    f"0:{stream_index}",
                    str(target),
                ]
            )
            created.append(target)
        except subprocess.CalledProcessError as exc:
            skipped.append(
                {
                    "index": stream_index,
                    "codec_name": codec_name,
                    "reason": exc.stderr or "ffmpeg extraction failed",
                }
            )

    return created, skipped


def maybe_transcribe(
    audio_path: Path | None,
    output_dir: Path,
    mode: str,
    transcribe: str,
    language: str | None,
    whisper_model: str,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "status": "skipped",
        "reason": "transcription not requested",
        "files": [],
    }

    if mode == "technical" or transcribe == "off":
        return result
    if audio_path is None:
        return {"status": "skipped", "reason": "no extracted audio", "files": []}
    if not shutil.which("whisper"):
        return {
            "status": "skipped",
            "reason": "local whisper executable not found",
            "files": [],
        }

    output_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        "whisper",
        str(audio_path),
        "--model",
        whisper_model,
        "--task",
        "transcribe",
        "--output_dir",
        str(output_dir),
        "--output_format",
        "all",
        "--fp16",
        "False",
    ]
    if language:
        cmd.extend(["--language", language])

    try:
        run_command(cmd)
    except subprocess.CalledProcessError as exc:
        return {
            "status": "failed",
            "reason": exc.stderr or "whisper transcription failed",
            "files": [],
        }

    files = sorted(output_dir.glob(f"{audio_path.stem}*"))
    return {
        "status": "completed",
        "reason": "",
        "files": [str(path) for path in files],
    }


def build_summary(
    input_path: Path,
    probe_data: dict[str, Any],
    sidecar_subtitles: list[Path],
    extracted_subtitles: list[Path],
    skipped_subtitles: list[dict[str, Any]],
    frames: list[Path],
    audio_path: Path | None,
    transcription: dict[str, Any],
) -> dict[str, Any]:
    format_info = probe_data.get("format", {})
    streams = probe_data.get("streams", [])

    video_streams = []
    audio_streams = []
    subtitle_streams = []

    for stream in streams:
        codec_type = stream.get("codec_type")
        stream_summary = {
            "index": stream.get("index"),
            "codec_name": stream.get("codec_name"),
            "language": stream.get("tags", {}).get("language", "und"),
        }
        if codec_type == "video":
            stream_summary.update(
                {
                    "width": stream.get("width"),
                    "height": stream.get("height"),
                    "frame_rate": parse_frame_rate(stream.get("r_frame_rate")),
                    "pix_fmt": stream.get("pix_fmt"),
                }
            )
            video_streams.append(stream_summary)
        elif codec_type == "audio":
            stream_summary.update(
                {
                    "channels": stream.get("channels"),
                    "sample_rate": stream.get("sample_rate"),
                }
            )
            audio_streams.append(stream_summary)
        elif codec_type == "subtitle":
            subtitle_streams.append(stream_summary)

    return {
        "input": {
            "path": str(input_path),
            "size_bytes": input_path.stat().st_size,
        },
        "format": {
            "format_name": format_info.get("format_name"),
            "duration_seconds": format_info.get("duration"),
            "duration_hms": format_seconds(format_info.get("duration")),
            "bit_rate": format_info.get("bit_rate"),
        },
        "streams": {
            "video": video_streams,
            "audio": audio_streams,
            "subtitle": subtitle_streams,
        },
        "artifacts": {
            "sidecar_subtitles": [str(path) for path in sidecar_subtitles],
            "extracted_subtitles": [str(path) for path in extracted_subtitles],
            "skipped_subtitles": skipped_subtitles,
            "frames": [str(path) for path in frames],
            "audio": str(audio_path) if audio_path else None,
            "transcription": transcription,
        },
    }


def write_markdown_report(summary: dict[str, Any], output_path: Path) -> None:
    streams = summary["streams"]
    artifacts = summary["artifacts"]
    format_info = summary["format"]
    input_info = summary["input"]

    lines = [
        "# Video Analysis Report",
        "",
        "## Input",
        f"- Path: `{input_info['path']}`",
        f"- Size: `{input_info['size_bytes']}` bytes",
        f"- Format: `{format_info['format_name']}`",
        f"- Duration: `{format_info['duration_hms']}`",
        f"- Bit rate: `{format_info['bit_rate']}`",
        "",
        "## Video streams",
    ]

    if streams["video"]:
        for stream in streams["video"]:
            lines.append(
                f"- Stream {stream['index']}: {stream['codec_name']}, "
                f"{stream['width']}x{stream['height']}, {stream['frame_rate']}, "
                f"language={stream['language']}"
            )
    else:
        lines.append("- None")

    lines.extend(["", "## Audio streams"])
    if streams["audio"]:
        for stream in streams["audio"]:
            lines.append(
                f"- Stream {stream['index']}: {stream['codec_name']}, "
                f"channels={stream['channels']}, sample_rate={stream['sample_rate']}, "
                f"language={stream['language']}"
            )
    else:
        lines.append("- None")

    lines.extend(["", "## Subtitle streams"])
    if streams["subtitle"]:
        for stream in streams["subtitle"]:
            lines.append(
                f"- Stream {stream['index']}: {stream['codec_name']}, language={stream['language']}"
            )
    else:
        lines.append("- None")

    lines.extend(["", "## Artifacts"])
    lines.append(f"- Sidecar subtitles: {len(artifacts['sidecar_subtitles'])}")
    lines.append(f"- Extracted subtitles: {len(artifacts['extracted_subtitles'])}")
    lines.append(f"- Sampled frames: {len(artifacts['frames'])}")
    lines.append(f"- Audio export: `{artifacts['audio']}`")
    lines.append(
        f"- Transcription: {artifacts['transcription']['status']} "
        f"({artifacts['transcription']['reason']})"
    )

    if artifacts["skipped_subtitles"]:
        lines.extend(["", "## Subtitle extraction limits"])
        for item in artifacts["skipped_subtitles"]:
            lines.append(
                f"- Stream {item['index']} ({item['codec_name']}): {item['reason']}"
            )

    lines.extend(
        [
            "",
            "## Suggested reading order",
            "- Read `summary.json` for structured machine-friendly metadata.",
            "- Read extracted subtitle or transcript files before inferring speech from frames.",
            "- Use the sampled frames to verify slides, captions, and scene changes.",
        ]
    )

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    ensure_dependency("ffprobe")
    ensure_dependency("ffmpeg")

    input_path = Path(args.input).expanduser().resolve()
    if not input_path.is_file():
        print(f"[ERROR] Input video not found: {input_path}", file=sys.stderr)
        return 2
    if args.frame_interval <= 0:
        print("[ERROR] --frame-interval must be greater than zero", file=sys.stderr)
        return 2
    if args.max_frames <= 0:
        print("[ERROR] --max-frames must be greater than zero", file=sys.stderr)
        return 2

    output_dir = (
        Path(args.output_dir).expanduser().resolve()
        if args.output_dir
        else Path.cwd() / "video-analysis" / input_path.stem
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    probe_data = run_ffprobe(input_path)
    ffprobe_path = output_dir / "ffprobe.json"
    ffprobe_path.write_text(json.dumps(probe_data, indent=2) + "\n", encoding="utf-8")

    sidecar_subtitles = find_sidecar_subtitles(input_path)
    streams = probe_data.get("streams", [])
    has_audio = any(stream.get("codec_type") == "audio" for stream in streams)

    frames: list[Path] = []
    audio_path: Path | None = None
    extracted_subtitles: list[Path] = []
    skipped_subtitles: list[dict[str, Any]] = []

    if args.mode == "summary":
        frames = extract_frames(
            input_path=input_path,
            output_dir=output_dir / "frames",
            frame_interval=args.frame_interval,
            max_frames=args.max_frames,
        )
    if args.mode in {"summary", "transcript"} and has_audio:
        audio_path = extract_audio(input_path, output_dir / "audio")
    if args.mode in {"summary", "transcript"}:
        extracted_subtitles, skipped_subtitles = extract_subtitles(
            input_path=input_path,
            streams=streams,
            output_dir=output_dir / "subtitles",
        )

    transcription = maybe_transcribe(
        audio_path=audio_path,
        output_dir=output_dir / "transcripts",
        mode=args.mode,
        transcribe=args.transcribe,
        language=args.language,
        whisper_model=args.whisper_model,
    )

    summary = build_summary(
        input_path=input_path,
        probe_data=probe_data,
        sidecar_subtitles=sidecar_subtitles,
        extracted_subtitles=extracted_subtitles,
        skipped_subtitles=skipped_subtitles,
        frames=frames,
        audio_path=audio_path,
        transcription=transcription,
    )

    summary_path = output_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    write_markdown_report(summary, output_dir / "report.md")

    print(f"[INFO] Analysis written to: {output_dir}")
    print(f"[INFO] ffprobe JSON: {ffprobe_path}")
    print(f"[INFO] Summary JSON: {summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
