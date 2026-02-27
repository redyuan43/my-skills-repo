#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="/home/ivan/github/meetings/meeting-recorder"
PY="$ROOT/venv/bin/python"

action="${1:-up}"

wait_status() {
  for _ in $(seq 1 10); do
    if (cd "$ROOT" && "$PY" recorder_cli.py status >/dev/null 2>&1); then
      return 0
    fi
    sleep 1
  done
  return 1
}

case "$action" in
  up)
    bash "$SKILL_DIR/check.sh" asr >/dev/null
    bash "$SKILL_DIR/server.sh" start >/dev/null
    if ! wait_status; then
      echo "❌ recorder server 未就绪"
      exit 1
    fi
    echo "✅ 会议录音链路已就绪（ASR+Recorder）"
    echo "下一步可执行："
    echo "  bash $SKILL_DIR/meeting.sh start"
    ;;
  down)
    bash "$SKILL_DIR/server.sh" stop
    echo "✅ recorder server 已停止"
    ;;
  start|stop|status|transcript)
    bash "$SKILL_DIR/meeting.sh" "$action"
    ;;
  summary)
    level="${2:-A}"
    bash "$SKILL_DIR/meeting.sh" summary "$level"
    ;;
  *)
    echo "usage: $0 {up|down|start|stop|status|transcript|summary A|B|C|D|E}"
    exit 2
    ;;
esac
