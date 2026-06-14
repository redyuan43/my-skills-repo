---
name: pinterest-media-downloader
description: Download the highest available quality media from Pinterest Pin URLs with `yt-dlp`, including videos, live wallpapers, GIF-like MP4 pins, and static photos/images. Use this skill whenever the user provides a `pinterest.com/pin/...` URL or asks to download/save/export Pinterest video, Pinterest photo, Pinterest image, pin media, 高清视频, 高清图片, or Pinterest 素材 to local files.
---

# Pinterest Media Downloader

## Overview

Use the bundled script instead of hand-assembling `yt-dlp` commands. Pinterest pages often resolve to either HLS video streams or a single image URL, and local proxy environment variables can break `yt-dlp` in surprising ways. The wrapper probes the Pin, picks the right mode, sanitizes known-bad proxy variables for the subprocess, saves media into a predictable folder, and prints the resulting file paths.

## Standard Workflow

1. Confirm the input is a Pinterest Pin URL, usually like:

```text
https://www.pinterest.com/pin/81768549520405929/
```

2. Download to a task-specific directory. Prefer the user's Desktop when they are asking for a visible saved file:

```bash
python3 scripts/download_pinterest.py \
  --url "https://www.pinterest.com/pin/81768549520405929/" \
  --output-dir "$HOME/Desktop/Pinterest Downloads"
```

3. Verify the artifact before reporting success:

```bash
ls -lh "$HOME/Desktop/Pinterest Downloads"
ffprobe -v error -show_entries format=duration,size:stream=codec_type,codec_name,width,height \
  -of default=noprint_wrappers=1 "/path/to/downloaded.mp4"
```

For image-only Pins, verify with:

```bash
file "/path/to/downloaded.jpg"
identify "/path/to/downloaded.jpg"
```

4. Tell the user the exact local path, media type, dimensions or duration when available, and whether audio exists.

## Common Commands

Download auto-detected best media:

```bash
python3 scripts/download_pinterest.py \
  --url "<pinterest-pin-url>" \
  --output-dir "$HOME/Desktop/Pinterest Downloads"
```

Force video-oriented format selection:

```bash
python3 scripts/download_pinterest.py \
  --url "<pinterest-pin-url>" \
  --mode video \
  --output-dir "$HOME/Desktop/Pinterest Downloads"
```

Force image/photo download:

```bash
python3 scripts/download_pinterest.py \
  --url "<pinterest-pin-url>" \
  --mode photo \
  --output-dir "$HOME/Desktop/Pinterest Downloads"
```

Save metadata next to the media:

```bash
python3 scripts/download_pinterest.py \
  --url "<pinterest-pin-url>" \
  --write-info-json \
  --output-dir "$HOME/Desktop/Pinterest Downloads"
```

Use browser cookies if Pinterest blocks an otherwise public-looking Pin:

```bash
python3 scripts/download_pinterest.py \
  --url "<pinterest-pin-url>" \
  --cookies-from-browser chrome \
  --output-dir "$HOME/Desktop/Pinterest Downloads"
```

## Failure Handling

- If `yt-dlp` reports `Unsupported proxy type: "ftp"` or `Unsupported url scheme: "https"`, retry through this script. It removes the problematic `ftp_proxy` and `ALL_PROXY` values only for the download subprocess.
- If a Pin is private, deleted, age-gated, region-gated, or requires login, report the exact error. Retry with `--cookies-from-browser chrome` only when the browser profile is local and appropriate for the user's account.
- If `mode=auto` misclassifies a Pin, rerun with `--mode video` or `--mode photo`.
- Keep playlist downloading disabled. A Pin URL should save one primary media item unless the user explicitly asks for related media.
- Do not promise DRM bypass or access to private boards the user cannot view.

## Resources

- `scripts/download_pinterest.py`: Repeatable Pinterest media downloader.
- `references/runbook.md`: Notes from the first successful Pin download, including proxy cleanup and verification.
