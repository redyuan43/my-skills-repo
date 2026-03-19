#!/usr/bin/env bash
set -euo pipefail

PACKAGE_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb"
PACKAGE_PATH="/tmp/WeChatLinux_arm64.deb"
LAUNCH=0
PIN=0
DOWNLOAD_ONLY=0

usage() {
  cat <<'EOF'
install_wechat_official.sh [--package-url URL] [--package-path PATH] [--download-only] [--launch] [--pin]

Options:
  --package-url URL    Official WeChat Linux package URL.
  --package-path PATH   Local path for the downloaded .deb package.
  --download-only      Only download the package.
  --launch             Launch WeChat after installation.
  --pin                Pin wechat.desktop to GNOME favorites if available.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-url)
      PACKAGE_URL="${2:?missing value for --package-url}"
      shift 2
      ;;
    --package-path)
      PACKAGE_PATH="${2:?missing value for --package-path}"
      shift 2
      ;;
    --download-only)
      DOWNLOAD_ONLY=1
      shift
      ;;
    --launch)
      LAUNCH=1
      shift
      ;;
    --pin)
      PIN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

ARCH="$(uname -m)"
case "${ARCH}" in
  aarch64|arm64)
    ;;
  *)
    echo "This installer is intended for ARM Linux only. Detected architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

download_package() {
  echo "[wechat] downloading official package: ${PACKAGE_URL}"
  curl -fL "${PACKAGE_URL}" -o "${PACKAGE_PATH}"
  echo "[wechat] downloaded to: ${PACKAGE_PATH}"
}

install_package() {
  if dpkg -s wechat >/dev/null 2>&1; then
    echo "[wechat] package already installed"
    return
  fi

  echo "[wechat] installing package: ${PACKAGE_PATH}"
  sudo apt-get update
  sudo apt-get install -y "${PACKAGE_PATH}"
}

launch_wechat() {
  local display="${DISPLAY:-:0}"
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local xauthority="${XAUTHORITY:-/run/user/$(id -u)/gdm/Xauthority}"
  local bus="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

  if [[ ! -x /opt/wechat/wechat ]]; then
    echo "[wechat] launcher not found: /opt/wechat/wechat" >&2
    exit 1
  fi

  echo "[wechat] launching client in current session"
  setsid env \
    DISPLAY="${display}" \
    XAUTHORITY="${xauthority}" \
    XDG_RUNTIME_DIR="${runtime_dir}" \
    DBUS_SESSION_BUS_ADDRESS="${bus}" \
    nohup /opt/wechat/wechat >/tmp/wechat-official-setup.log 2>&1 < /dev/null &

  sleep 2
  pgrep -a -u "$(id -u)" -f '^/opt/wechat/wechat|/opt/wechat/RadiumWMPF/runtime/WeChatAppEx' || true
}

pin_to_gnome() {
  if ! command -v gsettings >/dev/null 2>&1; then
    echo "[wechat] gsettings not available, skipping pin"
    return
  fi

  local favorites
  favorites="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo "[]")"
  if [[ "${favorites}" != *"wechat.desktop"* ]]; then
    favorites="${favorites%]}"
    if [[ "${favorites}" == "[]" ]]; then
      favorites="['wechat.desktop']"
    else
      favorites="${favorites%, }"
      favorites="${favorites}, 'wechat.desktop']"
    fi
    gsettings set org.gnome.shell favorite-apps "${favorites}"
  fi
  echo "[wechat] GNOME favorites: $(gsettings get org.gnome.shell favorite-apps)"
}

download_package

if [[ "${DOWNLOAD_ONLY}" -eq 1 ]]; then
  exit 0
fi

install_package

if [[ ! -f /usr/share/applications/wechat.desktop ]]; then
  echo "[wechat] desktop entry not found after install" >&2
  exit 1
fi

if [[ "${PIN}" -eq 1 ]]; then
  pin_to_gnome
fi

if [[ "${LAUNCH}" -eq 1 ]]; then
  launch_wechat
fi

echo "[wechat] installed successfully"
