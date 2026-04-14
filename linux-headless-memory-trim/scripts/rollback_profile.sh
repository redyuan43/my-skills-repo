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

restore_gdm_wiring() {
  local unit_path="/usr/lib/systemd/system/gdm.service"
  local display_manager_link="/etc/systemd/system/display-manager.service"
  local graphical_wants_dir="/etc/systemd/system/graphical.target.wants"
  local graphical_wants_link="${graphical_wants_dir}/display-manager.service"

  if [[ ! -f "$unit_path" ]]; then
    echo "[skip] gdm unit file not found: $unit_path"
    return
  fi

  echo "[gdm] restore display-manager.service -> $unit_path"
  run ln -sfn "$unit_path" "$display_manager_link"

  echo "[gdm] ensure graphical.target wants display-manager.service"
  run mkdir -p "$graphical_wants_dir"
  run ln -sfn "$unit_path" "$graphical_wants_link"
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

restore_gdm_wiring

echo "[systemd] daemon-reload"
run systemctl daemon-reload

echo "Done. Mode=$MODE"
