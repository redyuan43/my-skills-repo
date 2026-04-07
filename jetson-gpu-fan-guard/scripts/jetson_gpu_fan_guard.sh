#!/usr/bin/env bash
set -euo pipefail

readonly GPU_TEMP_THRESHOLD_C="${GPU_TEMP_THRESHOLD_C:-70}"
readonly AUTO_RESUME_TEMP_C="${AUTO_RESUME_TEMP_C:-65}"
readonly POLL_INTERVAL_SEC="${POLL_INTERVAL_SEC:-2}"
readonly FAN_MAX_PWM="${FAN_MAX_PWM:-255}"
readonly NVFANCONTROL_SERVICE="${NVFANCONTROL_SERVICE:-nvfancontrol.service}"

gpu_zone_dir=""
tj_zone_dir=""
fan_pwm_node=""
current_mode="unknown"

log() {
  printf '[jetson-gpu-fan-guard] %s\n' "$*"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log "This script must run as root."
    exit 1
  fi
}

find_thermal_zone_dir() {
  local expected_type="$1"
  local type_file

  for type_file in /sys/class/thermal/thermal_zone*/type; do
    [[ -e "${type_file}" ]] || continue
    if [[ "$(<"${type_file}")" == "${expected_type}" ]]; then
      dirname "${type_file}"
      return 0
    fi
  done

  return 1
}

find_fan_pwm_node() {
  local node

  for node in \
    /sys/devices/platform/pwm-fan*/hwmon/hwmon*/pwm* \
    /sys/bus/i2c/drivers/f75308/*/hwmon/hwmon*/pwm*; do
    [[ -e "${node}" ]] || continue
    printf '%s\n' "${node}"
    return 0
  done

  return 1
}

gpu_temp_c() {
  local temp_raw
  temp_raw="$(<"${gpu_zone_dir}/temp")"
  printf '%d\n' "$((temp_raw / 1000))"
}

apply_manual_max() {
  systemctl stop "${NVFANCONTROL_SERVICE}" || true
  printf 'user_space\n' > "${tj_zone_dir}/policy"
  printf '%s\n' "${FAN_MAX_PWM}" > "${fan_pwm_node}"
}

set_manual_max() {
  if [[ "${current_mode}" == "manual_max" ]]; then
    return 0
  fi

  apply_manual_max
  current_mode="manual_max"
  log "GPU temperature >= ${GPU_TEMP_THRESHOLD_C}C, switched fan to manual max (${FAN_MAX_PWM})."
}

set_auto_mode() {
  if [[ "${current_mode}" == "auto" ]]; then
    return 0
  fi

  systemctl reset-failed "${NVFANCONTROL_SERVICE}" >/dev/null 2>&1 || true
  if ! systemctl start "${NVFANCONTROL_SERVICE}"; then
    apply_manual_max
    current_mode="manual_max"
    log "Failed to restore automatic fan control, keeping fan at manual max."
    return 0
  fi

  current_mode="auto"
  log "GPU temperature <= ${AUTO_RESUME_TEMP_C}C, restored automatic fan control."
}

cleanup() {
  set +e
  systemctl --no-block start "${NVFANCONTROL_SERVICE}" >/dev/null 2>&1
}

main() {
  require_root

  gpu_zone_dir="$(find_thermal_zone_dir "gpu-thermal")" || {
    log "Unable to find gpu-thermal zone."
    exit 1
  }
  tj_zone_dir="$(find_thermal_zone_dir "tj-thermal")" || {
    log "Unable to find tj-thermal zone."
    exit 1
  }
  fan_pwm_node="$(find_fan_pwm_node)" || {
    log "Unable to find fan PWM node."
    exit 1
  }

  trap cleanup EXIT INT TERM

  if (( AUTO_RESUME_TEMP_C >= GPU_TEMP_THRESHOLD_C )); then
    log "AUTO_RESUME_TEMP_C must be lower than GPU_TEMP_THRESHOLD_C."
    exit 1
  fi

  log "Watching ${gpu_zone_dir}/temp with high threshold ${GPU_TEMP_THRESHOLD_C}C and resume threshold ${AUTO_RESUME_TEMP_C}C."
  log "Using fan node ${fan_pwm_node}."

  while true; do
    local_temp_c="$(gpu_temp_c)"

    if (( local_temp_c >= GPU_TEMP_THRESHOLD_C )); then
      set_manual_max
    elif (( local_temp_c <= AUTO_RESUME_TEMP_C )); then
      set_auto_mode
    fi

    sleep "${POLL_INTERVAL_SEC}"
  done
}

main "$@"
