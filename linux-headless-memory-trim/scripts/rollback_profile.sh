#!/usr/bin/env bash
set -euo pipefail

MODE="dry-run"
if [[ "${1:-}" == "--apply" ]]; then
  MODE="apply"
elif [[ "${1:-}" == "--dry-run" || -z "${1:-}" ]]; then
  MODE="dry-run"
else
  echo "Usage: $0 [--dry-run|--apply]"
  exit 1
fi

services=(
  docker.service
  containerd.service
  snapd.service
  avahi-daemon.service
  ModemManager.service
  bluetooth.service
  gdm.service
)

sockets=(
  docker.socket
  snapd.socket
  avahi-daemon.socket
)

run() {
  if [[ "$MODE" == "apply" ]]; then
    sudo "$@"
  else
    echo "[dry-run] sudo $*"
  fi
}

for s in "${sockets[@]}"; do
  if systemctl list-unit-files "$s" --no-legend >/dev/null 2>&1; then
    echo "[socket] enable --now $s"
    run systemctl enable --now "$s" || true
  fi
done

for s in "${services[@]}"; do
  if systemctl list-unit-files "$s" --no-legend >/dev/null 2>&1; then
    echo "[service] enable --now $s"
    run systemctl enable --now "$s" || true
  fi
done

echo "[target] set-default graphical.target"
run systemctl set-default graphical.target

echo "Done. Mode=$MODE"
