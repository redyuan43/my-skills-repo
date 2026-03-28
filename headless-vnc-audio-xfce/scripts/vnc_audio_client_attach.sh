#!/usr/bin/env bash
set -euo pipefail

# Run this on the Linux client, not on the VNC host.
: "${VNC_AUDIO_SERVER:?Set VNC_AUDIO_SERVER to the VNC host IP or hostname}"
VNC_AUDIO_PORT="${VNC_AUDIO_PORT:-4713}"
VNC_AUDIO_COOKIE="${VNC_AUDIO_COOKIE:-$HOME/.config/pulse/vnc-audio.cookie}"
LOCAL_SINK="${LOCAL_SINK:-@DEFAULT_SINK@}"
REMOTE_SOURCE="${REMOTE_SOURCE:-vnc_audio.monitor}"
LATENCY_MSEC="${LATENCY_MSEC:-120}"

if [[ ! -f "$VNC_AUDIO_COOKIE" ]]; then
  echo "Missing cookie: $VNC_AUDIO_COOKIE" >&2
  exit 1
fi

echo "Attached remote audio. Press Ctrl+C to detach."
PULSE_COOKIE="$VNC_AUDIO_COOKIE" \
parec \
  --server="tcp:${VNC_AUDIO_SERVER}:${VNC_AUDIO_PORT}" \
  --device="${REMOTE_SOURCE}" \
  --raw \
  --fix-format \
  --fix-rate \
  --fix-channels \
  --latency-msec="${LATENCY_MSEC}" | \
pacat \
  --playback \
  --device="${LOCAL_SINK}" \
  --latency-msec="${LATENCY_MSEC}"
