---
name: download-youtube-video
description: Download YouTube videos, playlists, audio tracks, subtitles, thumbnails, and metadata with `yt-dlp`. Use when a user provides a YouTube URL and wants a local media file, an audio-only export, subtitle or transcript artifacts, metadata for later analysis, or a reproducible download command. Also use when a previous agent failed to scrape the watch page directly and the correct fallback is to fetch the actual artifacts instead.
---

# Download Youtube Video

## Overview

Use `scripts/download_youtube.py` instead of assembling `yt-dlp` commands ad hoc. The wrapper provides stable presets for full video downloads, audio-only extraction, subtitles-only retrieval, and metadata capture.

## Workflow

1. Confirm the target outcome before downloading:
- Full video file
- Audio-only file
- Subtitles or transcript artifacts
- Metadata only

2. Choose a destination directory. Prefer a task-specific folder so downstream agents can find the artifacts without guessing.

3. Run the wrapper script from this skill:

```bash
python3 scripts/download_youtube.py --url "<youtube-url>" --mode video
```

4. Read the output directory after the command completes. Prefer the downloaded media file plus `.info.json`, subtitles, and description text when another agent needs to continue analysis.

## Common commands

Download the best merged video:

```bash
python3 scripts/download_youtube.py \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --mode video \
  --video-format mp4 \
  --output-dir ./downloads/youtube
```

Extract audio only:

```bash
python3 scripts/download_youtube.py \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --mode audio \
  --audio-format mp3 \
  --output-dir ./downloads/youtube
```

Fetch subtitles and auto-subtitles without the video:

```bash
python3 scripts/download_youtube.py \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --mode subtitles \
  --subtitle-langs "en.*,zh.*,ja.*" \
  --output-dir ./downloads/youtube
```

Capture metadata only:

```bash
python3 scripts/download_youtube.py \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --mode metadata \
  --output-dir ./downloads/youtube
```

## Failure handling

- If a direct webpage fetch returns only the YouTube shell page, do not keep retrying HTML scraping. Switch to this skill and download the real artifacts.
- If `yt-dlp` reports private, members-only, age-restricted, or region-restricted content, report the exact error. Only use `--cookies <file>` when the user explicitly provides a cookie export file.
- Do not promise downloads for DRM-protected streams. Report the limitation directly.
- Use `--dry-run` first when you only need to verify the generated command shape.
- Keep playlist download disabled unless the user explicitly wants the whole playlist.

## Resources

- `scripts/download_youtube.py`: Wrapper around `yt-dlp` with repeatable presets.
- `references/yt_dlp_presets.md`: Quick recipes and parameter choices for common download tasks.

## Notes

- Use this skill for acquisition. Use `analyze-video-file` after the media is local and the next task is understanding or summarizing the content.
