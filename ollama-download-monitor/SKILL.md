---
name: ollama-download-monitor
description: Install Ollama and monitor model download completion from pull logs. Use when the user asks to install Ollama on Linux/macOS/Windows, start one or more `ollama pull` downloads, track progress in real time, or verify that model downloads finished successfully.
---

# Ollama Download Monitor

Use this skill to set up Ollama and monitor model download success from terminal logs.

## Workflow

1. Install Ollama first.
2. Start model downloads with log files.
3. Run the monitor script to track progress and completion.
4. Verify final state with `ollama list`.

For installation steps, read:
- `ollama-download-monitor/references/install-ollama.md`

## Start Downloads With Logs

Use one terminal command per model and keep each model in its own log file:

```bash
LOG_DIR=/tmp/ollama-pull-logs
mkdir -p "$LOG_DIR"

ollama pull gpt-oss:20b 2>&1 | tee "$LOG_DIR/gpt-oss_20b.log"
ollama pull qwen3-vl 2>&1 | tee "$LOG_DIR/qwen3-vl.log"
```

For parallel pulls, run each command in a separate terminal session.

## Monitor Progress

Run the bundled script:

```bash
bash ollama-download-monitor/scripts/monitor_ollama_logs.sh \
  --models "gpt-oss:20b,qwen3-vl,glm-4.7-flash" \
  --log-dir /tmp/ollama-pull-logs \
  --interval 20
```

Behavior:
- Detect progress percent, size, speed, and ETA from each log file
- Show `DONE` when a `success` line is found
- Show `WAITING` if the log exists but no progress line is found yet
- Show `LOG_MISSING` if no log file exists

## Verify Download Completion

After monitor shows done, verify with:

```bash
ollama list
```

A model is considered ready when:
- monitor reports `DONE`
- model appears in `ollama list`

## Troubleshooting

- If all models stay `LOG_MISSING`, confirm your `--log-dir` path.
- If `ollama pull` fails immediately, verify Ollama is running:
  - Linux with systemd: `systemctl status ollama`
  - otherwise: start server with `ollama serve`
- If progress stalls for a long time, check network connectivity and available disk space.
