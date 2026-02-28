#!/usr/bin/env bash
set -euo pipefail

MODELS_CSV=""
LOG_DIR="/tmp/ollama-pull-logs"
INTERVAL=60
WATCH=1

usage() {
  cat <<'USAGE'
Usage:
  download_and_monitor_ollama.sh --models "model1,model2" [--log-dir /path] [--interval 60] [--no-watch]

Examples:
  bash ollama-download-monitor/scripts/download_and_monitor_ollama.sh \
    --models "gpt-oss:20b,qwen3-vl,glm-4.7-flash" \
    --interval 60
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
      --no-watch)
        WATCH=0
        shift
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

is_model_done() {
  local model="$1"
  local list_out
  list_out="$(ollama list 2>/dev/null | awk 'NR>1{print $1}')"
  if echo "$list_out" | grep -Fxq "$model"; then
    return 0
  fi
  if [[ "$model" != *:* ]] && echo "$list_out" | grep -Fxq "${model}:latest"; then
    return 0
  fi
  return 1
}

is_pull_running() {
  local model="$1"
  ps -eo cmd | grep -F "ollama pull ${model}" | grep -v "grep -F" >/dev/null 2>&1
}

start_pull_detached() {
  local model="$1"
  local safe_name log_file
  safe_name="$(sanitize_model_name "$model")"
  log_file="$LOG_DIR/${safe_name}.log"

  if is_model_done "$model"; then
    echo "DONE     $model (already in ollama list)"
    return
  fi

  if is_pull_running "$model"; then
    echo "RUNNING  $model (already pulling)"
    return
  fi

  # Detach pull process from current terminal so downloads continue after shell exits.
  setsid bash -lc "exec ollama pull '$model' >> '$log_file' 2>&1" >/dev/null 2>&1 &
  echo "STARTED  $model (pid $!, log: $log_file)"
}

main() {
  parse_args "$@"

  if ! command -v ollama >/dev/null 2>&1; then
    echo "ollama command not found" >&2
    exit 1
  fi

  local script_dir monitor_script
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  monitor_script="$script_dir/monitor_ollama_logs.sh"
  if [[ ! -x "$monitor_script" ]]; then
    echo "Monitor script not found or not executable: $monitor_script" >&2
    exit 1
  fi

  mkdir -p "$LOG_DIR"
  IFS=',' read -r -a models <<< "$MODELS_CSV"

  echo "========================================"
  echo "Ollama Download Starter"
  echo "Start: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Log directory: $LOG_DIR"
  echo "========================================"
  for model in "${models[@]}"; do
    model="$(echo "$model" | xargs)"
    [[ -z "$model" ]] && continue
    start_pull_detached "$model"
  done

  if [[ "$WATCH" -eq 1 ]]; then
    echo
    echo "Entering monitor mode..."
    bash "$monitor_script" --models "$MODELS_CSV" --log-dir "$LOG_DIR" --interval "$INTERVAL"
  else
    echo
    echo "Monitor disabled (--no-watch)."
    echo "Run:"
    echo "  bash \"$monitor_script\" --models \"$MODELS_CSV\" --log-dir \"$LOG_DIR\" --interval \"$INTERVAL\""
  fi
}

main "$@"
