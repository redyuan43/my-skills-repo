# Pinterest Media Downloader Runbook

## First verified case

Input:

```text
https://www.pinterest.com/pin/81768549520405929/
```

Direct `yt-dlp` initially failed on this machine with:

```text
Unsupported proxy type: "ftp" (urllib), Unsupported url scheme: "https" (websockets)
```

Cause: the shell had `ftp_proxy=ftp://127.0.0.1:10808` and `ALL_PROXY=socks5://127.0.0.1:10808`. Removing `ftp_proxy`, `FTP_PROXY`, `ALL_PROXY`, and `all_proxy` for the single `yt-dlp` subprocess allowed the normal `https_proxy/http_proxy` settings to work.

Successful manual probe:

```bash
env -u ftp_proxy -u FTP_PROXY -u ALL_PROXY -u all_proxy \
  yt-dlp --no-playlist --print title --print duration --print ext \
  "https://www.pinterest.com/pin/81768549520405929/"
```

Observed result:

- Title: `Perfect Red Eyes Live Wallpaper`
- Duration: about `30.33` seconds
- Extension: `mp4`

Successful output:

- Path: `$HOME/Desktop/Pinterest Downloads/Perfect Red Eyes Live Wallpaper [81768549520405929].mp4`
- Size: about `5.8M`
- Video: H.264, `704x1376`
- Audio: AAC
- Duration: about `30.35` seconds

## Verification commands

For videos:

```bash
ffprobe -v error \
  -show_entries format=duration,size:stream=codec_type,codec_name,width,height \
  -of default=noprint_wrappers=1 \
  "/path/to/downloaded.mp4"
```

For images:

```bash
file "/path/to/downloaded.jpg"
identify "/path/to/downloaded.jpg"
```

If ImageMagick `identify` is unavailable, use `file` plus `python3 -m pip show pillow` only when Pillow is already installed. Do not add dependencies just for basic verification.
