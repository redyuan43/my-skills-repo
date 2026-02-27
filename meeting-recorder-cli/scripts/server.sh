#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/ivan/github/meetings/meeting-recorder"
PY="$ROOT/venv/bin/python"
LOG="/tmp/meeting_recorder.log"

cmd="${1:-status}"

case "$cmd" in
  start)
    if pgrep -af "python.*recorder_server.py" >/dev/null 2>&1; then
      echo "recorder_server already running"
      exit 0
    fi
    cd "$ROOT"
    nohup "$PY" recorder_server.py >/tmp/meeting_recorder.stdout 2>&1 &
    sleep 1
    pgrep -af "python.*recorder_server.py" || true
    ;;
  stop)
    pkill -f "python.*recorder_server.py" || true
    ;;
  status)
    pgrep -af "python.*recorder_server.py" || true
    if [[ -f "$LOG" ]]; then
      echo "--- tail $LOG ---"
      tail -n 20 "$LOG"
    fi
    ;;
  *)
    echo "usage: $0 {start|stop|status}"
    exit 2
    ;;
esac
