# Podcast download presets

## Use the wrapper first

Prefer `python3 scripts/download_podcast.py` for repeatable agent behavior. Drop to raw `yt-dlp` only when the wrapper is missing a flag the user explicitly needs.

## Recommended presets

- Podcast page to original audio:
  `python3 scripts/download_podcast.py --url "<url>" --mode audio`
- Podcast page to MP3:
  `python3 scripts/download_podcast.py --url "<url>" --mode audio --audio-format mp3`
- Metadata only:
  `python3 scripts/download_podcast.py --url "<url>" --mode metadata`
- Retry with browser cookies:
  `python3 scripts/download_podcast.py --url "<url>" --mode audio --cookies-from-browser chrome`

## Operational rules

- Save each episode into a dedicated output directory so the audio file, thumbnail, description, and `.info.json` stay together.
- Keep the original container by default. Transcode only when the user explicitly wants MP3, M4A, OPUS, or WAV.
- For Xiaoyuzhou and similar podcast pages, a generic extractor result is acceptable if it resolves to a real audio URL.
- Use metadata-only mode when the user only wants title, artwork, or show notes.

## Access limits

- Gated or login-required podcast pages may need browser cookies or a user-provided cookies file.
- DRM-protected streams are out of scope for `yt-dlp`.
- Report exact stderr when retrieval fails.
