#!/usr/bin/env bash
set -euo pipefail

VNC_AUDIO_SINK="${VNC_AUDIO_SINK:-vnc_audio}"
VNC_AUDIO_PORT="${VNC_AUDIO_PORT:-4713}"
PULSE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pulse"
COOKIE_PATH="${VNC_AUDIO_COOKIE:-$PULSE_DIR/vnc-audio.cookie}"
PREV_SINK_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/vnc-audio-prev-sink"

wait_for_pulse() {
  local _i
  for _i in $(seq 1 20); do
    if pactl info >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  echo "PulseAudio is not ready" >&2
  exit 1
}

default_iface() {
  ip -o -4 route show to default | awk 'NR==1 { print $5 }'
}

listen_ip() {
  local iface
  iface="$(default_iface)"
  if [[ -n "$iface" ]]; then
    ip -o -4 addr show dev "$iface" scope global | awk 'NR==1 { split($4, parts, \"/\"); print parts[1] }'
  fi
}

listen_cidr() {
  local iface
  iface="$(default_iface)"
  if [[ -n "$iface" ]]; then
    ip -o -4 addr show dev "$iface" scope global | awk 'NR==1 { print $4 }'
  fi
}

module_loaded() {
  local pattern
  pattern="$1"
  pactl list short modules | grep -Eq "$pattern"
}

mkdir -p "$PULSE_DIR" "$(dirname "$PREV_SINK_FILE")"

if [[ ! -f "$COOKIE_PATH" ]]; then
  if [[ -f "$PULSE_DIR/cookie" ]]; then
    install -m 600 "$PULSE_DIR/cookie" "$COOKIE_PATH"
  else
    dd if=/dev/urandom of="$COOKIE_PATH" bs=256 count=1 status=none
    chmod 600 "$COOKIE_PATH"
  fi
fi

if ! pgrep -x pulseaudio >/dev/null 2>&1; then
  pulseaudio --start >/dev/null 2>&1 || true
fi

wait_for_pulse

if ! module_loaded "module-null-sink.*sink_name=${VNC_AUDIO_SINK}([[:space:]]|$)"; then
  pactl load-module module-null-sink \
    "sink_name=${VNC_AUDIO_SINK}" \
    "sink_properties=device.description=VNC_Audio" >/dev/null
fi

current_default="$(pactl get-default-sink 2>/dev/null || true)"
if [[ -n "$current_default" && "$current_default" != "$VNC_AUDIO_SINK" ]]; then
  printf '%s\n' "$current_default" > "$PREV_SINK_FILE"
fi

pactl set-default-sink "$VNC_AUDIO_SINK"

while read -r sink_input_id _rest; do
  [[ -n "$sink_input_id" ]] || continue
  pactl move-sink-input "$sink_input_id" "$VNC_AUDIO_SINK" >/dev/null 2>&1 || true
done < <(pactl list short sink-inputs)

current_ip="$(listen_ip)"
current_cidr="$(listen_cidr)"
auth_acl="127.0.0.1"
if [[ -n "$current_cidr" ]]; then
  auth_acl="${auth_acl};${current_cidr}"
fi

if [[ -z "$current_ip" ]]; then
  current_ip="127.0.0.1"
fi

if ! module_loaded "module-native-protocol-tcp"; then
  pactl load-module module-native-protocol-tcp \
    "port=${VNC_AUDIO_PORT}" \
    "listen=${current_ip}" \
    "auth-cookie=${COOKIE_PATH}" \
    "auth-anonymous=0" \
    "auth-ip-acl=${auth_acl}" >/dev/null
fi
