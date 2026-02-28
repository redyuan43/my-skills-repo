# Generated artifacts

## Core files

- `ffprobe.json`: Raw container and stream metadata from `ffprobe`.
- `summary.json`: Structured digest intended for machine consumption.
- `report.md`: Human-readable summary of streams, artifacts, and limitations.

## Optional artifact folders

- `frames/`: Time-sampled JPG frames for scene and slide inspection.
- `audio/audio.wav`: Mono 16 kHz WAV intended for ASR or manual listening.
- `subtitles/`: Embedded subtitle tracks extracted into text formats when possible.
- `transcripts/`: Local Whisper outputs when a `whisper` executable is available.

## Reading order

1. Read subtitle or transcript text first when the user asks for spoken content.
2. Read `report.md` for a concise technical overview.
3. Read `summary.json` when another script or agent needs structured data.
4. Inspect `frames/` to verify visuals, diagrams, subtitles burned into the image, and scene changes.

## Known limits

- Image-based subtitle codecs may not convert to text automatically.
- A silent or music-only video will still produce technical artifacts but not meaningful transcripts.
- Frame sampling is interval-based, so very short on-screen events can be missed unless `--frame-interval` is lowered.
