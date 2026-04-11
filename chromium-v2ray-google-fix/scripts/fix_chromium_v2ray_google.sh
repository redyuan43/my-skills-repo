#!/usr/bin/env bash
set -euo pipefail

PROXY_PORT="${PROXY_PORT:-10808}"
HTTP_PROXY_URL="http://127.0.0.1:${PROXY_PORT}/"
SOCKS_PROXY_URL="socks5://127.0.0.1:${PROXY_PORT}"
WRAPPER_PATH="${HOME}/bin/chromium-v2ray-launcher"
LOCAL_BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
USER_DESKTOP="${DESKTOP_DIR}/org.chromium.Chromium.desktop"
DESKTOP_SHORTCUT="${HOME}/Desktop/Chromium.desktop"
LOCAL_CHROMIUM="${LOCAL_BIN_DIR}/chromium"
ACTIVE_CONNECTION_FILTER="${ACTIVE_CONNECTION_FILTER:-802-3-ethernet|802-11-wireless}"

usage() {
  cat <<'EOF'
Usage:
  bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh diagnose
  bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh apply-wrapper
  bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh desktop
  bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh set-dns
  bash chromium-v2ray-google-fix/scripts/fix_chromium_v2ray_google.sh all [--with-dns]
EOF
}

write_wrapper() {
  mkdir -p "${HOME}/bin" "${LOCAL_BIN_DIR}" "${DESKTOP_DIR}"

  cat > "${WRAPPER_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export http_proxy="${HTTP_PROXY_URL}"
export https_proxy="${HTTP_PROXY_URL}"
export ftp_proxy="${HTTP_PROXY_URL}"
export all_proxy="${SOCKS_PROXY_URL}"
export HTTP_PROXY="\$http_proxy"
export HTTPS_PROXY="\$https_proxy"
export FTP_PROXY="\$ftp_proxy"
export ALL_PROXY="\$all_proxy"
export no_proxy="localhost,127.0.0.0/8,::1"
export NO_PROXY="\$no_proxy"

exec flatpak run org.chromium.Chromium \
  --proxy-server="${SOCKS_PROXY_URL}" \
  --proxy-bypass-list="<-loopback>" \
  --disable-quic \
  --disable-features="DnsOverHttps,AsyncDns,UseDnsHttpsSvcb,Vulkan,VaapiVideoDecoder,VaapiVideoEncoder,UseChromeOSDirectVideoDecoder" \
  --disable-gpu \
  --disable-gpu-compositing \
  --disable-accelerated-2d-canvas \
  --disable-accelerated-video-decode \
  --disable-accelerated-video-encode \
  --use-gl=swiftshader \
  --disable-software-rasterizer \
  --ozone-platform=x11 \
  "\$@"
EOF

  cat > "${LOCAL_CHROMIUM}" <<EOF
#!/usr/bin/env bash
exec "${WRAPPER_PATH}" "\$@"
EOF

  chmod +x "${WRAPPER_PATH}" "${LOCAL_CHROMIUM}"
}

write_desktop_entry() {
  mkdir -p "${DESKTOP_DIR}" "${HOME}/Desktop"

  cat > "${USER_DESKTOP}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Chromium
Comment=Launch Chromium via local wrapper
Exec=${LOCAL_CHROMIUM} %U
Icon=org.chromium.Chromium
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
StartupWMClass=chromium-browser
MimeType=text/html;text/xml;application/xhtml_xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

  cat > "${DESKTOP_SHORTCUT}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Chromium
Comment=Launch Chromium via local wrapper
Exec=${LOCAL_CHROMIUM} %U
Icon=org.chromium.Chromium
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
StartupWMClass=chromium-browser
EOF

  chmod +x "${DESKTOP_SHORTCUT}"
  update-desktop-database "${DESKTOP_DIR}" >/dev/null 2>&1 || true
  gio set "${DESKTOP_SHORTCUT}" metadata::trusted true >/dev/null 2>&1 || true
}

set_xdg_defaults() {
  xdg-settings set default-web-browser org.chromium.Chromium.desktop 2>/dev/null || true
  xdg-mime default org.chromium.Chromium.desktop x-scheme-handler/http 2>/dev/null || true
  xdg-mime default org.chromium.Chromium.desktop x-scheme-handler/https 2>/dev/null || true
  xdg-mime default org.chromium.Chromium.desktop text/html 2>/dev/null || true
}

set_dns() {
  mapfile -t active_connections < <(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | rg "${ACTIVE_CONNECTION_FILTER}" | cut -d: -f1)

  if [[ ${#active_connections[@]} -eq 0 ]]; then
    echo "No active wired/wifi NetworkManager connections found." >&2
    return 1
  fi

  for name in "${active_connections[@]}"; do
    sudo nmcli connection modify "${name}" \
      ipv4.ignore-auto-dns yes \
      ipv4.dns "1.1.1.1 8.8.8.8" \
      ipv6.ignore-auto-dns yes \
      ipv6.dns "2606:4700:4700::1111 2001:4860:4860::8888"
    sudo nmcli connection up "${name}" >/dev/null
  done

  sudo resolvectl flush-caches >/dev/null 2>&1 || true
}

diagnose() {
  echo "[processes]"
  ps -ef | rg -i 'xray|v2ray|v2rayn|clash|mihomo|sing-box|chrome|chromium' || true
  echo
  echo "[ports]"
  ss -lntp | rg '1080|10808|10809|7890|7897|20170|20171|3128|8080' || true
  echo
  echo "[proxy env]"
  env | rg -i 'proxy|http_proxy|https_proxy|all_proxy|no_proxy' || true
  echo
  echo "[curl google]"
  curl -I --max-time 20 "https://www.google.com" || true
  echo
  echo "[curl google via socks]"
  curl -I --max-time 20 --socks5-hostname "127.0.0.1:${PROXY_PORT}" "https://www.google.com" || true
  echo
  echo "[dns]"
  resolvectl query www.google.com 2>/dev/null || true
  getent hosts www.google.com || true
}

cmd="${1:-}"
case "${cmd}" in
  diagnose)
    diagnose
    ;;
  apply-wrapper)
    write_wrapper
    write_desktop_entry
    set_xdg_defaults
    ;;
  desktop)
    write_desktop_entry
    ;;
  set-dns)
    set_dns
    ;;
  all)
    write_wrapper
    write_desktop_entry
    set_xdg_defaults
    if [[ "${2:-}" == "--with-dns" ]]; then
      set_dns
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
