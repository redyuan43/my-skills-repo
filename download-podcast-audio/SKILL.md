---
name: download-podcast-audio
description: Download podcast episode audio, show notes, thumbnails, and metadata with `yt-dlp`. Use when a user provides a Xiaoyuzhou episode URL, a direct MP3/M4A/OPUS audio URL, or another podcast episode page that resolves to a downloadable audio file and wants a local audio artifact plus sidecar metadata.
---

# Download Podcast Audio

## Overview

Use `scripts/download_podcast.py` instead of assembling `yt-dlp` commands ad hoc. The wrapper is tuned for podcast episodes where the primary output is audio plus sidecar files such as `.info.json`, description text, and artwork.

## Workflow

1. Confirm the target outcome:
- Audio file
- Metadata only
- Keep original audio container or transcode to a specific format

2. Choose a dedicated output directory so later analysis can find the audio and sidecar files together.

3. Run the wrapper:

```bash
python3 scripts/download_podcast.py --url "<episode-url>" --mode audio
```

4. After download, inspect the output directory and prefer the audio file plus `.info.json`, description text, and thumbnail sidecars.

## Common commands

Download a Xiaoyuzhou episode and keep the original audio container:

```bash
python3 scripts/download_podcast.py \
  --url "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID" \
  --mode audio \
  --output-dir ./downloads/podcasts
```

Download a podcast page and normalize the output to MP3:

```bash
python3 scripts/download_podcast.py \
  --url "https://example.com/podcast/episode-123" \
  --mode audio \
  --audio-format mp3 \
  --output-dir ./downloads/podcasts
```

Capture only metadata and show notes:

```bash
python3 scripts/download_podcast.py \
  --url "https://www.xiaoyuzhoufm.com/episode/EPISODE_ID" \
  --mode metadata \
  --output-dir ./downloads/podcasts
```

Retry a gated page through browser cookies:

```bash
python3 scripts/download_podcast.py \
  --url "https://example.com/podcast/episode-123" \
  --mode audio \
  --cookies-from-browser chrome \
  --output-dir ./downloads/podcasts
```

## Failure handling

- If `yt-dlp` falls back to the generic extractor but still resolves a direct audio file, accept that path. For podcast pages this is often enough.
- If the page resolves to audio but the audio download fails, report the exact `yt-dlp` stderr instead of assuming the episode is unavailable.
- If the site requires login or region access, retry with `--cookies-from-browser` or a user-provided `--cookies` file.
- Keep playlist behavior disabled unless the user explicitly wants a full feed or series.
- Do not promise DRM-protected or streaming-only content when `yt-dlp` cannot produce a downloadable file.

## Resources

- `scripts/download_podcast.py`: Wrapper around `yt-dlp` for podcast pages and direct audio URLs.
- `references/presets.md`: Quick command presets and operating rules.

## Notes

- This skill is for acquisition. Use `asr` or `analyze-video-file` after the audio is local and the next step is transcription or content analysis.
- Xiaoyuzhou single-episode pages work through the generic extractor when the page exposes a direct media URL.
