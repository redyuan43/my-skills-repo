#!/usr/bin/env bash
set -euo pipefail

threshold_c="70"
resume_threshold_c=""
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_script="${script_dir}/jetson_gpu_fan_guard.sh"
target_script="/usr/local/bin/jetson_gpu_fan_guard.sh"
target_service="/etc/systemd/system/jetson-gpu-fan-guard.service"

usage() {
  cat <<'EOF'
Usage:
  sudo bash jetson-gpu-fan-guard/scripts/install_jetson_gpu_fan_guard.sh [--threshold 70] [--resume-threshold 65]

Options:
  --threshold N         Set the high temperature threshold in Celsius. Default: 70
  --resume-threshold N  Set the auto-resume threshold in Celsius. Default: threshold - 5
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold)
      if [[ $# -lt 2 ]]; then
        echo "缺少 --threshold 的参数值。"
        usage
        exit 1
      fi
      threshold_c="$2"
      shift 2
      ;;
    --resume-threshold)
      if [[ $# -lt 2 ]]; then
        echo "缺少 --resume-threshold 的参数值。"
        usage
        exit 1
      fi
      resume_threshold_c="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

if ! [[ "${threshold_c}" =~ ^[0-9]+$ ]]; then
  echo "阈值必须是整数摄氏度，例如 70。"
  exit 1
fi

if [[ -z "${resume_threshold_c}" ]]; then
  resume_threshold_c="$((threshold_c - 5))"
fi

if ! [[ "${resume_threshold_c}" =~ ^[0-9]+$ ]]; then
  echo "恢复阈值必须是整数摄氏度，例如 65。"
  exit 1
fi

if (( resume_threshold_c >= threshold_c )); then
  echo "恢复阈值必须低于高温阈值。"
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "请使用 sudo 运行此安装脚本。"
  exit 1
fi

install -m 0755 "${source_script}" "${target_script}"

cat > "${target_service}" <<EOF
[Unit]
Description=Jetson GPU Temperature Fan Guard
After=multi-user.target nvfancontrol.service
Wants=nvfancontrol.service

[Service]
Type=simple
ExecStart=/usr/local/bin/jetson_gpu_fan_guard.sh
Restart=always
RestartSec=2
Environment=GPU_TEMP_THRESHOLD_C=${threshold_c}
Environment=AUTO_RESUME_TEMP_C=${resume_threshold_c}
Environment=POLL_INTERVAL_SEC=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable jetson-gpu-fan-guard.service >/dev/null 2>&1 || true
systemctl restart jetson-gpu-fan-guard.service

if systemctl is-active --quiet jetson-gpu-fan-guard.service; then
  echo "jetson-gpu-fan-guard.service 已启动。"
else
  echo "jetson-gpu-fan-guard.service 启动失败。"
  exit 1
fi

journalctl -u jetson-gpu-fan-guard.service -n 10 --no-pager || true
