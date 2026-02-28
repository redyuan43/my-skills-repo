---
name: analyze-video-file
description: Analyze local video files with `ffprobe` and `ffmpeg`, extract metadata, frames, audio, subtitles, and transcript-ready artifacts, and generate a structured report for later summarization. Use when a user asks what a video file contains, needs a transcript workflow, wants key frames, or needs technical inspection of codecs, duration, resolution, and streams.
---

# Analyze Video File

## Overview

Use `scripts/analyze_video.py` to turn a local video file into structured artifacts another agent can read. The script produces `ffprobe` JSON, a Markdown report, extracted frames, extracted audio, and subtitle artifacts when available.

## Workflow

1. Decide the intent:
- `summary`: Understand the content. Produce frames, audio, subtitles, and a report.
- `transcript`: Focus on speech extraction and transcript artifacts.
- `technical`: Inspect codecs, streams, duration, and container details only.

2. Run the wrapper:

```bash
python3 scripts/analyze_video.py --input /path/to/video.mp4
```

3. Read the generated artifacts in this order:
- `report.md`
- `summary.json`
- Extracted subtitles or transcript files
- Sampled frames
- Extracted audio if a separate ASR step is still needed

## Common commands

Run the default summary pipeline:

```bash
python3 scripts/analyze_video.py \
  --input /path/to/video.mp4 \
  --output-dir ./video-analysis
```

Technical-only inspection:

```bash
python3 scripts/analyze_video.py \
  --input /path/to/video.mp4 \
  --mode technical
```

Transcript-focused extraction:

```bash
python3 scripts/analyze_video.py \
  --input /path/to/video.mp4 \
  --mode transcript \
  --language zh
```

Increase frame density for a short clip:

```bash
python3 scripts/analyze_video.py \
  --input /path/to/video.mp4 \
  --frame-interval 10 \
  --max-frames 18
```

## Interpretation rules

- Prefer subtitle or transcript text over frame-only inference when the user asks what the speaker said.
- Use frames to validate scene changes, on-screen text, and slide transitions that the transcript misses.
- Use `technical` mode when the user only wants stream inspection or codec debugging.
- If the video originated from YouTube or another hosted page, use `download-youtube-video` first to get a stable local file.

## Failure handling

- If there is no audio stream, skip transcription claims and rely on frames plus subtitles.
- If embedded subtitles are image-based and extraction fails, report that limitation and keep the `ffprobe` details in the report.
- If no ASR tool is available, still extract a mono 16 kHz WAV so the next step can transcribe it cleanly.
- Keep output artifacts together under one directory; do not scatter files next to the source video unless the user asks for that.

## Resources

- `scripts/analyze_video.py`: Main wrapper for `ffprobe`, `ffmpeg`, and optional local Whisper transcription.
- `references/report_fields.md`: What each generated artifact means and how to use it in later reasoning.

## Notes

- This skill is for local media files. It does not fetch remote URLs by itself.
