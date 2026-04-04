#!/usr/bin/env bash
set -euo pipefail

VNC_AUDIO_SINK="${VNC_AUDIO_SINK:-vnc_audio}"
VNC_AUDIO_PORT="${VNC_AUDIO_PORT:-4713}"
PULSE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pulse"
COOKIE_PATH="${VNC_AUDIO_COOKIE:-$PULSE_DIR/vnc-audio.cookie}"

iface="$(ip -o -4 route show to default | awk 'NR==1 { print $5 }')"
listen_ip=""
if [[ -n "$iface" ]]; then
  listen_ip="$(ip -o -4 addr show dev "$iface" scope global | awk 'NR==1 { split($4, parts, "/"); print parts[1] }')"
fi

printf 'default sink: %s\n' "$(pactl get-default-sink 2>/dev/null || echo unknown)"
printf 'vnc sink present: '
if pactl list short sinks | awk '{print $2}' | grep -Fxq "$VNC_AUDIO_SINK"; then
  echo yes
else
  echo no
fi
printf 'pulse tcp module: '
if pactl list short modules | grep -q "module-native-protocol-tcp"; then
  echo loaded
else
  echo missing
fi
printf 'listen ip: %s\n' "${listen_ip:-unknown}"
printf 'listen port: %s\n' "$VNC_AUDIO_PORT"
printf 'cookie path: %s\n' "$COOKIE_PATH"
printf '\nmodules:\n'
pactl list short modules | grep -E "module-native-protocol-tcp|module-null-sink" || true
