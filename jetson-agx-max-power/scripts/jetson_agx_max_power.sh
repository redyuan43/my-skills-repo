#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="jetson-agx-max-power"
readonly MODEL_PATH="/proc/device-tree/model"
readonly NVP_CONF="/etc/nvpmodel.conf"
readonly STATE_ROOT="/var/tmp/${SCRIPT_NAME}-${USER}"
readonly STATE_FILE="${STATE_ROOT}/state.env"
readonly CLOCKS_FILE="${STATE_ROOT}/l4t_dfs.conf"

log() {
  printf '[%s] %s\n' "${SCRIPT_NAME}" "$*"
}

usage() {
  cat <<'EOF'
Usage:
  bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh status
  bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh 状态
  bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh max
  bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh 最大
  bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh restore
  bash jetson-agx-max-power/scripts/jetson_agx_max_power.sh 恢复
EOF
}

normalize_action() {
  case "${1:-}" in
    status|状态) echo "status" ;;
    max|最大) echo "max" ;;
    restore|恢复) echo "restore" ;;
    *) echo "${1:-}" ;;
  esac
}

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log "Missing required command: ${command_name}"
    exit 1
  fi
}

run_sudo() {
  if ! sudo -n true >/dev/null 2>&1; then
    log "This action requires passwordless sudo on this host."
    exit 1
  fi
  sudo -n "$@"
}

run_readonly_root_fallback() {
  if "$@" 2>/dev/null; then
    return 0
  fi
  run_sudo "$@"
}

machine_model() {
  tr -d '\0' < "${MODEL_PATH}"
}

require_supported_machine() {
  local model
  model="$(machine_model)"
  if [[ "${model}" != *"Jetson AGX Orin"* ]]; then
    log "Unsupported machine: ${model}"
    log "This skill only supports Jetson AGX Orin."
    exit 1
  fi
}

parse_default_mode_id() {
  sed -n 's/^< PM_CONFIG DEFAULT=\([0-9][0-9]*\) >/\1/p; s/^< PM_CONFIG DEFAULT=\([0-9][0-9]*\)>/\1/p' "${NVP_CONF}" | head -n 1
}

parse_modes() {
  sed -n 's/^< POWER_MODEL ID=\([0-9][0-9]*\) NAME=\([^ >][^ >]*\) >/\1\t\2/p' "${NVP_CONF}"
}

mode_name_by_id() {
  local mode_id="$1"
  parse_modes | awk -F '\t' -v mode_id="${mode_id}" '$1 == mode_id { print $2; exit }'
}

find_maxn_mode_id() {
  parse_modes | awk -F '\t' '$2 == "MAXN" { print $1; exit }'
}

current_mode_id() {
  nvpmodel -q 2>/dev/null | awk 'NR == 2 { print $1; exit }'
}

current_mode_name() {
  nvpmodel -q 2>/dev/null | sed -n 's/^NV Power Mode: //p' | head -n 1
}

mode_list_pretty() {
  local default_mode_id="$1"
  parse_modes | while IFS=$'\t' read -r mode_id mode_name; do
    if [[ -z "${mode_id}" ]]; then
      continue
    fi
    if [[ "${mode_id}" == "${default_mode_id}" ]]; then
      printf '  - %s = %s (default)\n' "${mode_id}" "${mode_name}"
    else
      printf '  - %s = %s\n' "${mode_id}" "${mode_name}"
    fi
  done
}

show_clocks_summary() {
  run_readonly_root_fallback jetson_clocks --show | awk '
    /^Online CPUs:/ { print; next }
    /^GPU / { print; next }
    /^EMC / { print; next }
    /^NV Power Mode:/ { print; next }
  '
}

state_exists() {
  [[ -f "${STATE_FILE}" && -f "${CLOCKS_FILE}" ]]
}

load_state() {
  if ! state_exists; then
    return 1
  fi
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
}

save_state() {
  local saved_mode_id="$1"
  local saved_mode_name="$2"

  mkdir -p "${STATE_ROOT}"
  run_sudo jetson_clocks --store "${CLOCKS_FILE}" >/dev/null

  cat > "${STATE_FILE}" <<EOF
SAVED_MODE_ID='${saved_mode_id}'
SAVED_MODE_NAME='${saved_mode_name}'
CAPTURED_AT='$(date '+%Y-%m-%d %H:%M:%S')'
EOF
}

clear_state() {
  rm -f "${STATE_FILE}" "${CLOCKS_FILE}"
  rmdir "${STATE_ROOT}" 2>/dev/null || true
}

print_status() {
  local model current_id current_name default_mode_id default_mode_name maxn_mode_id
  model="$(machine_model)"
  current_id="$(current_mode_id)"
  current_name="$(current_mode_name)"
  default_mode_id="$(parse_default_mode_id)"
  default_mode_name="$(mode_name_by_id "${default_mode_id}")"
  maxn_mode_id="$(find_maxn_mode_id)"

  printf 'Model: %s\n' "${model}"
  printf 'Config: %s\n' "${NVP_CONF}"
  printf 'Current mode: %s (%s)\n' "${current_name:-unknown}" "${current_id:-unknown}"
  printf 'Default mode: %s (%s)\n' "${default_mode_name:-unknown}" "${default_mode_id:-unknown}"
  printf 'MAXN mode id: %s\n' "${maxn_mode_id:-not found}"
  printf 'Available modes:\n'
  mode_list_pretty "${default_mode_id}"
  printf 'Clock summary:\n'
  show_clocks_summary

  if load_state; then
    printf 'Restore snapshot: present\n'
    printf 'Snapshot captured at: %s\n' "${CAPTURED_AT:-unknown}"
    printf 'Snapshot target mode: %s (%s)\n' "${SAVED_MODE_NAME:-unknown}" "${SAVED_MODE_ID:-unknown}"
  else
    printf 'Restore snapshot: absent\n'
  fi
}

apply_max() {
  local current_id current_name maxn_mode_id current_after_name current_after_id

  current_id="$(current_mode_id)"
  current_name="$(current_mode_name)"
  maxn_mode_id="$(find_maxn_mode_id)"

  if [[ -z "${maxn_mode_id}" ]]; then
    log "Unable to find a MAXN mode in ${NVP_CONF}."
    exit 1
  fi

  if state_exists; then
    log "Existing restore snapshot found. Keeping original pre-max state."
  else
    log "Capturing current mode and clocks state."
    save_state "${current_id}" "${current_name}"
  fi

  log "Switching nvpmodel to MAXN (mode ${maxn_mode_id})."
  run_sudo nvpmodel -m "${maxn_mode_id}" >/dev/null

  log "Applying jetson_clocks."
  run_sudo jetson_clocks >/dev/null

  current_after_id="$(current_mode_id)"
  current_after_name="$(current_mode_name)"
  printf 'Applied mode: %s (%s)\n' "${current_after_name:-unknown}" "${current_after_id:-unknown}"
  printf 'Clock summary after max:\n'
  show_clocks_summary
}

restore_previous_state() {
  local mode_after_restore_name mode_after_restore_id

  if ! load_state; then
    log "No saved restore snapshot found."
    exit 1
  fi

  log "Restoring nvpmodel mode ${SAVED_MODE_NAME} (${SAVED_MODE_ID})."
  run_sudo nvpmodel -m "${SAVED_MODE_ID}" >/dev/null

  log "Restoring jetson_clocks state."
  run_sudo jetson_clocks --restore "${CLOCKS_FILE}" >/dev/null

  mode_after_restore_id="$(current_mode_id)"
  mode_after_restore_name="$(current_mode_name)"
  if [[ "${mode_after_restore_id}" != "${SAVED_MODE_ID}" ]]; then
    log "Restore verification failed: expected mode ${SAVED_MODE_ID}, got ${mode_after_restore_id:-unknown}."
    exit 1
  fi

  printf 'Restored mode: %s (%s)\n' "${mode_after_restore_name:-unknown}" "${mode_after_restore_id:-unknown}"
  printf 'Clock summary after restore:\n'
  show_clocks_summary

  clear_state
}

main() {
  local action
  action="$(normalize_action "${1:-}")"

  case "${action}" in
    status|max|restore) ;;
    -h|--help|"")
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac

  require_command nvpmodel
  require_command jetson_clocks
  [[ -r "${MODEL_PATH}" ]] || { log "Unable to read ${MODEL_PATH}."; exit 1; }
  [[ -r "${NVP_CONF}" ]] || { log "Unable to read ${NVP_CONF}."; exit 1; }
  require_supported_machine

  case "${action}" in
    status)
      print_status
      ;;
    max)
      apply_max
      ;;
    restore)
      restore_previous_state
      ;;
  esac
}

main "$@"
