# Runbook

## Paths

- Project root: `/home/ivan/github/meetings`
- Recorder root: `/home/ivan/github/meetings/meeting-recorder`
- Recordings: `/home/ivan/github/meetings/recordings`

## Core Commands

```bash
cd /home/ivan/github/meetings/opencode-skills/meeting-recorder-cli
bash scripts/onekey.sh up
bash scripts/onekey.sh start
bash scripts/onekey.sh stop
bash scripts/onekey.sh summary A
bash scripts/onekey.sh transcript
```

## Troubleshooting

### ASR service not ready

```bash
bash scripts/check.sh asr
```

Expected:
- `/api/health` returns HTTP 200
- `/api/status` contains `status=ready`

### Recorder server not responding

```bash
bash scripts/check.sh recorder
```

Expected:
- `recorder_server.py` process exists
- `/tmp/meeting_recorder.log` has no fatal stack trace

### Transcript mostly empty

- Check audio environment and selected default input.
- Check latest `segment_*.wav` and `segment_*.txt` under today's meeting directory.
- Re-run with clearer voice and avoid silent environment.
