# yt-dlp presets

## Use the wrapper first

Prefer `python3 scripts/download_youtube.py` for repeatable agent behavior. Drop to raw `yt-dlp` only when the wrapper is missing a specific flag the user explicitly needs.

## Recommended presets

- Full video, merged to MP4:
  `python3 scripts/download_youtube.py --url "<url>" --mode video --video-format mp4`
- Best available container:
  `python3 scripts/download_youtube.py --url "<url>" --mode video --video-format best`
- Audio only:
  `python3 scripts/download_youtube.py --url "<url>" --mode audio --audio-format mp3`
- Subtitles only:
  `python3 scripts/download_youtube.py --url "<url>" --mode subtitles --subtitle-langs "en.*,zh.*"`
- Hardened YouTube subtitle pull through browser cookies:
  `python3 scripts/download_youtube.py --url "<url>" --mode subtitles --subtitle-langs "zh-Hans,en-orig,en" --cookies-from-browser chrome --js-runtime "node:/home/$USER/.local/bin/node" --remote-components`
- Metadata only:
  `python3 scripts/download_youtube.py --url "<url>" --mode metadata`

## Operational rules

- Keep `--no-playlist` behavior unless the user explicitly asks for playlist-wide retrieval.
- Save into a dedicated output directory for each task so later agents can find the media and sidecar files.
- Use `--write-info-json` when another step will analyze title, channel, upload date, or chapter metadata.
- Use `--mode subtitles` before full download when the only goal is understanding the spoken content.
- If `--list-subs` shows automatic captions but download still fails, promote the hardened subtitle preset before declaring subtitle retrieval blocked.
- When using browser cookies, prefer a real logged-in browser profile over a stale cookies export.

## Access limits

- Private, members-only, region-locked, or age-gated videos may require a user-provided cookies file.
- DRM-protected content is out of scope for `yt-dlp`.
- Report exact stderr from `yt-dlp` when access fails instead of paraphrasing vaguely.
- `HTTP 429` on subtitle URLs is a retry/identity problem, not automatically a content-availability problem.
