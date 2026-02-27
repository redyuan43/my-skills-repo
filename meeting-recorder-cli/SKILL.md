---
name: meeting-recorder-cli
description: Operate the meetings project recorder via recorder_cli.py with an external ASR HTTP service (default 127.0.0.1:8001). Use this when users want to start/stop/status/transcript/summary meeting workflows, diagnose recording-to-transcription issues, or run the end-to-end meeting minutes pipeline in /home/ivan/github/meetings.
---

# Meeting Recorder CLI Skill

Use this skill for `/home/ivan/github/meetings/meeting-recorder`.

## When To Use

- User asks to run meeting recording from CLI (`start`, `stop`, `status`, `transcript`, `summary`).
- User asks to verify meeting recording -> ASR -> transcript -> summary chain.
- User asks to diagnose "recording started but no transcript" in this project.

## Preconditions

1. Recorder project path exists:
`/home/ivan/github/meetings/meeting-recorder`
2. ASR HTTP service is reachable at `http://127.0.0.1:8001` (or configured base URL).
3. Python venv exists at `meeting-recorder/venv`.

## Canonical Workflow

1. One-key bring-up (ASR check + server ready):
`bash scripts/onekey.sh up`
2. Start meeting:
`bash scripts/onekey.sh start`
3. Stop meeting:
`bash scripts/onekey.sh stop`
4. Generate summary (A/B/C/D/E):
`bash scripts/onekey.sh summary A`
5. Read transcript:
`bash scripts/onekey.sh transcript`

## Diagnostics Workflow

1. Verify ASR HTTP:
`bash scripts/check.sh asr`
2. Verify recorder server process/log:
`bash scripts/check.sh recorder`
3. Verify CLI connection:
`bash scripts/meeting.sh status`
4. If transcript is empty, inspect latest meeting dir under:
`/home/ivan/github/meetings/recordings/YYYY-MM-DD/*_meeting`

## Notes

- This project now uses ASR HTTP by default via `config.yaml` (`asr.mode: http`).
- CLI status is real server state (not local-only print).
- `start` and `stop` are separate commands and can run in separate CLI sessions.

For command details and outputs, see `references/runbook.md`.
