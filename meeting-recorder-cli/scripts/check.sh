#!/usr/bin/env bash
set -euo pipefail

kind="${1:-all}"

check_asr() {
  echo "== ASR health =="
  curl -sS -m 5 http://127.0.0.1:8001/api/health || true
  echo
  echo "== ASR status =="
  curl -sS -m 5 http://127.0.0.1:8001/api/status || true
  echo
}

check_recorder() {
  echo "== recorder process =="
  pgrep -af "python.*recorder_server.py" || true
  echo
  if [[ -f /tmp/meeting_recorder.log ]]; then
    echo "== recorder log tail =="
    tail -n 30 /tmp/meeting_recorder.log
  else
    echo "no /tmp/meeting_recorder.log yet"
  fi
}

case "$kind" in
  asr)
    check_asr
    ;;
  recorder)
    check_recorder
    ;;
  all)
    check_asr
    check_recorder
    ;;
  *)
    echo "usage: $0 {asr|recorder|all}"
    exit 2
    ;;
esac
