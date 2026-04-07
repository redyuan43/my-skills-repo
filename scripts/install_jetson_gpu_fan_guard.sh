#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source_script="${repo_root}/scripts/jetson_gpu_fan_guard.sh"
source_service="${repo_root}/systemd/system/jetson-gpu-fan-guard.service"
target_script="/usr/local/bin/jetson_gpu_fan_guard.sh"
target_service="/etc/systemd/system/jetson-gpu-fan-guard.service"

if [[ "${EUID}" -ne 0 ]]; then
  echo "请使用 sudo 运行此安装脚本。"
  exit 1
fi

install -m 0755 "${source_script}" "${target_script}"
install -d "/etc/systemd/system"
install -m 0644 "${source_service}" "${target_service}"

systemctl daemon-reload
systemctl enable --now jetson-gpu-fan-guard.service

systemctl status jetson-gpu-fan-guard.service --no-pager -n 20
