#!/usr/bin/env bash
set -euo pipefail

EDGE_HOST="edge"
V2RAY_CONFIG="$HOME/.local/share/v2rayN/binConfigs/config.json"
REMOTE_DIR="~/.local/share/edge-xray"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  edge_tailscale_proxy_bootstrap.sh [--edge edge] [--v2ray-config PATH]
USAGE
}

while (($#)); do
  case "$1" in
    --edge) EDGE_HOST="${2:?missing --edge value}"; shift 2 ;;
    --v2ray-config) V2RAY_CONFIG="${2:?missing --v2ray-config value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

test -r "$V2RAY_CONFIG"
for cmd in ssh scp curl jq unzip; do command -v "$cmd" >/dev/null; done

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

asset_url="$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.assets[] | select(.name | test("Xray-linux-arm64-v8a\\.zip$")) | .browser_download_url' | head -1)"
curl -fL "$asset_url" -o "$tmpdir/xray.zip"
unzip -q "$tmpdir/xray.zip" -d "$tmpdir/xray"

ssh "$EDGE_HOST" "mkdir -p $REMOTE_DIR"
scp "$tmpdir/xray/xray" "$tmpdir/xray/geoip.dat" "$tmpdir/xray/geosite.dat" "$V2RAY_CONFIG" "$EDGE_HOST:$REMOTE_DIR/"
scp "$SCRIPT_DIR/edge_copy_id_batch.sh" "$EDGE_HOST:~/edge-copy-id-batch.sh"
ssh "$EDGE_HOST" 'chmod +x ~/.local/share/edge-xray/xray'

ssh "$EDGE_HOST" 'cat > ~/edge-bootstrap-tailscale-proxy.sh' <<'REMOTE_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
XRAY_DIR="$USER_HOME/.local/share/edge-xray"
PROXY_PORT="${PROXY_PORT:-10808}"
HTTP_PROXY_URL="http://127.0.0.1:${PROXY_PORT}/"
SOCKS_PROXY_URL="socks5://127.0.0.1:${PROXY_PORT}"
NO_PROXY_VALUE="localhost,127.0.0.0/8,::1,*.local,*.lan,*.ts.net,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"

sudo tee /etc/systemd/system/edge-xray.service >/dev/null <<SERVICE
[Unit]
Description=Headless Xray proxy for edge bootstrap
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$XRAY_DIR
ExecStart=$XRAY_DIR/xray run -c $XRAY_DIR/config.json
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now edge-xray.service
for _ in {1..30}; do ss -ltn | grep -q "127.0.0.1:${PROXY_PORT}" && break; sleep 1; done
ss -ltn | grep -q "127.0.0.1:${PROXY_PORT}"

mkdir -p "$USER_HOME/.config/environment.d"
cat >"$USER_HOME/.config/environment.d/90-v2rayn-proxy.conf" <<ENV
ALL_PROXY=$SOCKS_PROXY_URL
all_proxy=$SOCKS_PROXY_URL
HTTP_PROXY=$HTTP_PROXY_URL
http_proxy=$HTTP_PROXY_URL
HTTPS_PROXY=$HTTP_PROXY_URL
https_proxy=$HTTP_PROXY_URL
NO_PROXY=$NO_PROXY_VALUE
no_proxy=$NO_PROXY_VALUE
ENV
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/environment.d/90-v2rayn-proxy.conf"

if ! command -v tailscale >/dev/null 2>&1; then
  tmp_install="$(mktemp)"
  HTTPS_PROXY="$HTTP_PROXY_URL" HTTP_PROXY="$HTTP_PROXY_URL" ALL_PROXY="$SOCKS_PROXY_URL" curl -fsSL https://tailscale.com/install.sh -o "$tmp_install"
  HTTPS_PROXY="$HTTP_PROXY_URL" HTTP_PROXY="$HTTP_PROXY_URL" ALL_PROXY="$SOCKS_PROXY_URL" sh "$tmp_install"
  rm -f "$tmp_install"
fi

sudo mkdir -p /etc/systemd/system/tailscaled.service.d
sudo tee /etc/systemd/system/tailscaled.service.d/proxy.conf >/dev/null <<ENV
[Service]
Environment=ALL_PROXY=$SOCKS_PROXY_URL
Environment=HTTP_PROXY=$HTTP_PROXY_URL
Environment=HTTPS_PROXY=$HTTP_PROXY_URL
Environment=NO_PROXY=$NO_PROXY_VALUE
ENV
sudo systemctl daemon-reload
sudo systemctl enable --now tailscaled.service
sudo systemctl restart tailscaled.service
tailscale status >/dev/null 2>&1 || sudo tailscale up
systemctl is-active edge-xray.service tailscaled.service
REMOTE_SCRIPT

ssh "$EDGE_HOST" 'chmod +x ~/edge-bootstrap-tailscale-proxy.sh ~/edge-copy-id-batch.sh && ~/edge-bootstrap-tailscale-proxy.sh'
