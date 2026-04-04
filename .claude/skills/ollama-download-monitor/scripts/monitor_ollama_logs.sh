#!/usr/bin/env bash
set -euo pipefail

MODELS_CSV=""
LOG_DIR="/tmp"
INTERVAL=60

usage() {
  cat <<'USAGE'
Usage:
  monitor_ollama_logs.sh --models "model1,model2" [--log-dir /path] [--interval 60]

Notes:
  - Each model is expected to have a log file in LOG_DIR.
  - Log filename format: model name with ':' and '/' replaced by '_', plus '.log'.
  - Example: gpt-oss:20b -> gpt-oss_20b.log
USAGE
}

sanitize_model_name() {
  local raw="$1"
  echo "$raw" | tr ':/ ' '___'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --models)
        MODELS_CSV="${2:-}"
        shift 2
        ;;
      --log-dir)
        LOG_DIR="${2:-}"
        shift 2
        ;;
      --interval)
        INTERVAL="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$MODELS_CSV" ]]; then
    echo "--models is required" >&2
    usage
    exit 1
  fi

  if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
    echo "--interval must be a positive integer" >&2
    exit 1
  fi
}

last_progress_line() {
  local log_file="$1"
  tail -n 20 "$log_file" 2>/dev/null | grep -E "pulling|success|error" | tail -n 1 || true
}

extract_field() {
  local line="$1"
  local pattern="$2"
  echo "$line" | grep -oE "$pattern" | tail -n 1 || true
}

print_model_status() {
  local model="$1"
  local safe_name
  safe_name="$(sanitize_model_name "$model")"
  local log_file="$LOG_DIR/${safe_name}.log"
  local legacy_log_file="$LOG_DIR/ollama_${safe_name}.log"

  echo "MODEL  $model"

  if [[ ! -f "$log_file" && -f "$legacy_log_file" ]]; then
    log_file="$legacy_log_file"
  fi

  if [[ ! -f "$log_file" ]]; then
    echo "STATE  LOG_MISSING"
    echo
    return
  fi

  local line
  line="$(last_progress_line "$log_file")"

  if [[ -z "$line" ]]; then
    echo "STATE  WAITING"
    echo
    return
  fi

  if echo "$line" | grep -qi "success"; then
    echo "STATE  DONE"
    echo
    return
  fi

  if echo "$line" | grep -qi "error"; then
    echo "STATE  ERROR"
    echo "INFO   $line"
    echo
    return
  fi

  local progress size speed eta
  progress="$(extract_field "$line" '[0-9]+%')"
  size="$(extract_field "$line" '[0-9.]+ [KMGT]B/[0-9.]+ [KMGT]B')"
  speed="$(extract_field "$line" '[0-9.]+ [KMGT]B/s')"
  eta="$(extract_field "$line" '[0-9]+h([0-9]+m)?|[0-9]+m([0-9]+s)?|[0-9]+s')"

  echo "STATE  DOWNLOADING"
  [[ -n "$progress" ]] && echo "PROG   $progress"
  [[ -n "$size" ]] && echo "SIZE   $size"
  [[ -n "$speed" ]] && echo "SPEED  $speed"
  [[ -n "$eta" ]] && echo "ETA    $eta"
  echo
}

main() {
  parse_args "$@"
  IFS=',' read -r -a models <<< "$MODELS_CSV"

  echo "========================================"
  echo "Ollama Download Monitor"
  echo "Start: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Log directory: $LOG_DIR"
  echo "Refresh every: ${INTERVAL}s"
  echo "========================================"

  while true; do
    clear
    echo "========================================"
    echo "Ollama Download Monitor  $(date '+%H:%M:%S')"
    echo "========================================"
    echo

    for model in "${models[@]}"; do
      model="$(echo "$model" | xargs)"
      [[ -z "$model" ]] && continue
      print_model_status "$model"
    done

    echo "Next update in ${INTERVAL}s. Press Ctrl+C to stop."
    sleep "$INTERVAL"
  done
}

main "$@"
