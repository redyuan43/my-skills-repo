---
name: cpu-process-watchflow
description: "Discover currently running high-CPU processes and then monitor user-selected processes with alerts when they stop or stay below a CPU threshold. Use when the user wants a two-step workflow: (1) list active high-load programs first, (2) pick specific programs to watch continuously and alert on failure."
---

# CPU Process Watchflow

Follow this exact two-step flow.

## Step 1: Discover high-load programs

Run:

```bash
python3 cpu-process-watchflow/scripts/find_high_cpu_processes.py --threshold 8 --top 20
```

Then report a concise table to the user, including:
- PID
- CPU%
- process name
- command line

Ask the user to confirm which processes should be monitored.

## Step 2: Monitor selected processes and alert

After the user selects process names or PIDs, run:

```bash
python3 cpu-process-watchflow/scripts/watch_processes.py \
  --names "python,ffmpeg" \
  --pids "1234,5678" \
  --interval 5 \
  --min-cpu 0.5 \
  --grace-checks 3
```

Rules:
- Alert immediately if a selected PID/name is no longer running.
- Alert when a process stays below `--min-cpu` for `--grace-checks` consecutive checks.
- Keep monitoring until interrupted.

## Recommended defaults

- Discovery threshold: `--threshold 8`
- Poll interval: `--interval 5`
- Low CPU threshold: `--min-cpu 0.5`
- Grace checks: `--grace-checks 3`

## Notes

- Name matching is case-insensitive and checks both executable name and full command line.
- PID monitoring is exact.
- On Linux/macOS the script uses `ps` by default; if `psutil` is available, it uses `psutil`.
