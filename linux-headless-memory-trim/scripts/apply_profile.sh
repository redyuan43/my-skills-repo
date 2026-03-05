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
  jtop.service
  docker.service
  containerd.service
  bluetooth.service
  ModemManager.service
  avahi-daemon.service
  openvpn.service
  snapd.service
  snap.cups.cupsd.service
  snap.cups.cups-browsed.service
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

for s in "${services[@]}"; do
  if systemctl list-unit-files "$s" --no-legend >/dev/null 2>&1; then
    echo "[service] disable --now $s"
    run systemctl disable --now "$s" || true
  else
    echo "[skip] service not found: $s"
  fi
done

for s in "${sockets[@]}"; do
  if systemctl list-unit-files "$s" --no-legend >/dev/null 2>&1; then
    echo "[socket] disable --now $s"
    run systemctl disable --now "$s" || true
  else
    echo "[skip] socket not found: $s"
  fi
done

echo "[target] set-default multi-user.target"
run systemctl set-default multi-user.target

echo "Done. Mode=$MODE"
