---
name: download-bilibili-video
description: Download Bilibili videos, audio, subtitles, danmaku, and metadata with `yt-dlp` using Bilibili-specific handling. Use when the user provides a `bilibili.com` or `b23.tv` URL and wants a local media file, subtitle artifacts, metadata for later analysis, or a repeatable download workflow that can use Chromium cookies to bypass 412 or login-gated access.
---

# Download Bilibili Video

## Overview

Use `scripts/download_bilibili.py` instead of assembling `yt-dlp` commands ad hoc. The wrapper handles Bilibili-specific cases:

- Expands `b23.tv` short URLs before download
- Uses `yt-dlp`'s built-in BiliBili extractor
- Detects local Chromium/Snap Chromium profiles for `--cookies-from-browser`
- Saves video, subtitles, danmaku, description, and `.info.json` together for downstream analysis

## Workflow

1. Confirm the target outcome:
- Full video
- Audio only
- Subtitles or danmaku only
- Metadata only

2. Choose a dedicated output directory so later analysis can find all artifacts.

3. Run the wrapper:

```bash
python3 scripts/download_bilibili.py --url "https://b23.tv/xxxxxxx" --mode video
```

4. After download, inspect the output directory and prefer the merged media file plus subtitle and metadata sidecars.

## Common commands

Download the best merged MP4 with subtitles and metadata:

```bash
python3 scripts/download_bilibili.py \
  --url "https://www.bilibili.com/video/BVxxxxxxxxx" \
  --mode video \
  --output-dir ./downloads/bilibili
```

Download from a short link and force Snap Chromium cookies:

```bash
python3 scripts/download_bilibili.py \
  --url "https://b23.tv/zinUqAv" \
  --browser-profile "$HOME/snap/chromium/common/chromium" \
  --mode video
```

Extract audio only:

```bash
python3 scripts/download_bilibili.py \
  --url "https://www.bilibili.com/video/BVxxxxxxxxx" \
  --mode audio \
  --audio-format mp3
```

Fetch subtitles, auto-subtitles, and danmaku without the video:

```bash
python3 scripts/download_bilibili.py \
  --url "https://www.bilibili.com/video/BVxxxxxxxxx" \
  --mode subtitles
```

Capture metadata only:

```bash
python3 scripts/download_bilibili.py \
  --url "https://www.bilibili.com/video/BVxxxxxxxxx" \
  --mode metadata
```

## Failure handling

- Cookie / 登录态确认规则：
  - 只有在用户明确确认可使用本机浏览器登录态，或明确提供 cookie 文件时，才启用 cookie 路径。
  - 优先使用 wrapper 的浏览器 profile 选项；raw cookie file 只用于用户主动提供的文件。
  - 不把 cookie、profile 内容或登录态信息写入仓库、日志或最终交付。
- If a `b23.tv` link fails directly, keep short-link expansion enabled and use the resolved `bilibili.com/video/BV...` URL.
- If Bilibili returns `412 Precondition Failed`, prefer Chromium cookies via `--cookies-from-browser`.
- If the machine uses Snap Chromium, set `--browser-profile "$HOME/snap/chromium/common/chromium"` or let the script auto-detect it.
- If content is private, region-restricted, members-only, or DRM-protected, report the exact `yt-dlp` error instead of retrying blindly.
- Keep playlist behavior disabled unless the user explicitly asks for an anthology or playlist-style download.

## Eval / Selftest

```bash
bash download-bilibili-video/scripts/selftest.sh --safe
```

Safe selftest only checks local files, Python syntax, eval JSON, failure taxonomy, and optional dependency presence. It does not contact Bilibili, read browser cookies, or write system state.

## Resources

- `scripts/download_bilibili.py`: Wrapper around `yt-dlp` for Bilibili downloads.
- `references/failure_taxonomy.md`: Failure classes, cookie confirmation rules, and output gates.
- `eval/val/items.json`: Validation prompts for short-link and login-gated behavior.

## Notes

- This skill is for acquisition. Use `analyze-video-file` after the media is local and the next step is content analysis.
- The wrapper prefers browser cookies over raw cookie files; only use `--cookies-file` when the user explicitly provides one.
