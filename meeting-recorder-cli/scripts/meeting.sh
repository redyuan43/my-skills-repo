#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/ivan/github/meetings/meeting-recorder"
PY="$ROOT/venv/bin/python"

sub="${1:-status}"
arg="${2:-}"

cd "$ROOT"

case "$sub" in
  start|stop|status|transcript)
    "$PY" recorder_cli.py "$sub"
    ;;
  summary)
    if [[ -z "$arg" ]]; then
      echo "usage: $0 summary {A|B|C|D|E}"
      exit 2
    fi
    "$PY" recorder_cli.py summary "$arg"
    ;;
  *)
    echo "usage: $0 {start|stop|status|transcript|summary A|B|C|D|E}"
    exit 2
    ;;
esac
