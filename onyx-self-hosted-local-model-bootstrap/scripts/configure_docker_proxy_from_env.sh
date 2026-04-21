#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "--yes" ]]; then
  echo "This script modifies Docker daemon proxy settings and restarts Docker."
  echo "Re-run with --yes after user confirmation."
  exit 2
fi

HTTP_PROXY_VALUE="${HTTP_PROXY:-${http_proxy:-}}"
HTTPS_PROXY_VALUE="${HTTPS_PROXY:-${https_proxy:-$HTTP_PROXY_VALUE}}"
NO_PROXY_VALUE="${NO_PROXY:-${no_proxy:-localhost,127.0.0.0/8,::1}}"

if [[ -z "$HTTP_PROXY_VALUE" && -z "$HTTPS_PROXY_VALUE" ]]; then
  echo "No HTTP_PROXY or HTTPS_PROXY found in current shell."
  exit 1
fi

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf >/dev/null <<EOF
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY_VALUE}"
Environment="HTTPS_PROXY=${HTTPS_PROXY_VALUE}"
Environment="NO_PROXY=${NO_PROXY_VALUE}"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
systemctl show docker --property=Environment
