#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SKILL_DIR}/../.." && pwd)"
RECORD_DIR="${REPO_ROOT}/var/recordings"
STATE_FILE="${RECORD_DIR}/face_track_live_record.state"

mkdir -p "${RECORD_DIR}"

usage() {
  cat <<'EOF'
Usage:
  bash skills/emeet-record-av-toggle/scripts/toggle_record.sh 开始 [output.mp4]
  bash skills/emeet-record-av-toggle/scripts/toggle_record.sh 停止
  bash skills/emeet-record-av-toggle/scripts/toggle_record.sh 状态
EOF
}

normalize_action() {
  case "${1:-}" in
    start|开始) echo "start" ;;
    stop|停止) echo "stop" ;;
    status|状态|"") echo "status" ;;
    *) echo "" ;;
  esac
}

is_running() {
  local pid="$1"
  kill -0 "${pid}" 2>/dev/null
}

load_state() {
  if [[ ! -f "${STATE_FILE}" ]]; then
    return 1
  fi
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
}

save_state() {
  local video_pid="$1"
  local audio_pid="$2"
  local output="$3"
  local video_path="$4"
  local audio_path="$5"
  local log="$6"
  cat >"${STATE_FILE}" <<EOF
VIDEO_PID=${video_pid}
AUDIO_PID=${audio_pid}
OUTPUT_PATH='${output}'
VIDEO_PATH='${video_path}'
AUDIO_PATH='${audio_path}'
LOG_PATH='${log}'
STARTED_AT='$(date '+%Y-%m-%d %H:%M:%S')'
EOF
}

clear_state() {
  rm -f "${STATE_FILE}"
}

action="$(normalize_action "${1:-}")"
if [[ -z "${action}" ]]; then
  usage
  exit 2
fi

case "${action}" in
  start)
    if load_state && (is_running "${VIDEO_PID}" || is_running "${AUDIO_PID}"); then
      echo "Recording already running"
      echo "Video PID: ${VIDEO_PID}"
      echo "Audio PID: ${AUDIO_PID}"
      echo "Output: ${OUTPUT_PATH}"
      echo "Log: ${LOG_PATH}"
      exit 0
    fi

    if [[ -n "${2:-}" ]]; then
      if [[ "${2}" = /* ]]; then
        output_path="${2}"
      else
        output_path="${RECORD_DIR}/${2}"
      fi
    else
      output_path="${RECORD_DIR}/face_track_talking_av_$(date '+%Y%m%d_%H%M%S').mp4"
    fi

    log_path="${RECORD_DIR}/face_track_talking_av_$(date '+%Y%m%d_%H%M%S').log"
    video_path="${output_path%.mp4}.video.mp4"
    audio_path="${output_path%.mp4}.audio.m4a"

    bash -lc "cd '${REPO_ROOT}' && exec .venv/bin/python -m emeet_pixy.apps.face_tracker \
      --camera 0 \
      --device /dev/video0 \
      --no-ui \
      --record-output '${video_path}' \
      --record-fps 30 \
      --log-level INFO" >"${log_path}" 2>&1 < /dev/null &
    video_pid=$!

    ffmpeg -hide_banner -loglevel error \
      -f alsa \
      -channels 1 \
      -sample_rate 48000 \
      -i hw:1,0 \
      -c:a aac \
      -y "${audio_path}" > /dev/null 2>&1 < /dev/null &
    audio_pid=$!

    save_state "${video_pid}" "${audio_pid}" "${output_path}" "${video_path}" "${audio_path}" "${log_path}"

    echo "Recording started"
    echo "Video PID: ${video_pid}"
    echo "Audio PID: ${audio_pid}"
    echo "Output: ${output_path}"
    echo "Log: ${log_path}"
    ;;

  stop)
    if ! load_state; then
      echo "No active recording state file"
      exit 1
    fi

    if ! is_running "${VIDEO_PID}" && ! is_running "${AUDIO_PID}"; then
      echo "Recording process is not running"
      echo "Last output: ${OUTPUT_PATH}"
      clear_state
      exit 1
    fi

    if is_running "${VIDEO_PID}"; then
      kill -TERM "${VIDEO_PID}"
    fi
    if is_running "${AUDIO_PID}"; then
      kill -TERM "${AUDIO_PID}"
    fi

    for _ in $(seq 1 80); do
      if ! is_running "${VIDEO_PID}" && ! is_running "${AUDIO_PID}"; then
        break
      fi
      sleep 0.5
    done

    if is_running "${VIDEO_PID}" || is_running "${AUDIO_PID}"; then
      echo "Recording is still shutting down"
      echo "Video PID: ${VIDEO_PID}"
      echo "Audio PID: ${AUDIO_PID}"
      echo "Output: ${OUTPUT_PATH}"
      exit 1
    fi

    ffmpeg -hide_banner -loglevel error -y \
      -i "${VIDEO_PATH}" \
      -i "${AUDIO_PATH}" \
      -c:v copy \
      -c:a aac \
      -shortest \
      "${OUTPUT_PATH}"

    echo "Recording stopped"
    echo "Output: ${OUTPUT_PATH}"
    echo "Log: ${LOG_PATH}"
    rm -f "${VIDEO_PATH}" "${AUDIO_PATH}"
    clear_state
    ;;

  status)
    if ! load_state; then
      echo "No active recording"
      exit 0
    fi

    if is_running "${VIDEO_PID}" || is_running "${AUDIO_PID}"; then
      echo "Recording running"
      echo "Video PID: ${VIDEO_PID}"
      echo "Audio PID: ${AUDIO_PID}"
      echo "Started: ${STARTED_AT}"
      echo "Output: ${OUTPUT_PATH}"
      echo "Log: ${LOG_PATH}"
    else
      echo "Recording not running"
      echo "Last output: ${OUTPUT_PATH}"
      echo "Last log: ${LOG_PATH}"
      clear_state
    fi
    ;;
esac
