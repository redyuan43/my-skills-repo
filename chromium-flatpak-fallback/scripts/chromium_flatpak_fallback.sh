#!/usr/bin/env bash
set -euo pipefail

APP_ID="org.chromium.Chromium"
FLATHUB_URL="https://flathub.org/repo/flathub.flatpakrepo"
USER_ID="$(id -u)"
DEFAULT_DISPLAY="${DISPLAY:-:1}"
DEFAULT_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${USER_ID}}"

usage() {
  cat <<'EOF'
Usage:
  chromium_flatpak_fallback.sh diagnose
  chromium_flatpak_fallback.sh install
  chromium_flatpak_fallback.sh launch [DISPLAY]
  chromium_flatpak_fallback.sh status
  chromium_flatpak_fallback.sh desktop
EOF
}

have() {
  command -v "$1" >/dev/null 2>&1
}

is_snap_wrapper() {
  [ -f /usr/bin/chromium-browser ] && grep -q '/snap/bin/chromium' /usr/bin/chromium-browser
}

diagnose() {
  echo "DISPLAY=${DISPLAY:-}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}"
  echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-}"
  echo "chromium-browser=$(command -v chromium-browser || true)"
  echo "chromium=$(command -v chromium || true)"
  echo "flatpak=$(command -v flatpak || true)"

  if is_snap_wrapper; then
    echo "chromium-browser is a Snap wrapper on this machine."
  fi

  if have snap; then
    local rc=0
    local out
    set +e
    out="$(snap run chromium --version 2>&1)"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
      echo "snap chromium ok: $out"
    else
      echo "snap chromium failed:"
      printf '%s\n' "$out" | sed -n '1,8p'
    fi
  else
    echo "snap command not found."
  fi

  if have flatpak && flatpak info --user "$APP_ID" >/dev/null 2>&1; then
    echo "Flatpak Chromium is already installed."
  else
    echo "Flatpak Chromium is not installed for this user."
  fi
}

install_app() {
  if ! have flatpak; then
    echo "flatpak is not installed." >&2
    exit 1
  fi

  flatpak --user remote-add --if-not-exists flathub "$FLATHUB_URL"
  flatpak --user install -y flathub "$APP_ID"
}

launch_app() {
  if ! have flatpak; then
    echo "flatpak is not installed." >&2
    exit 1
  fi

  if ! flatpak info --user "$APP_ID" >/dev/null 2>&1; then
    echo "Flatpak Chromium is not installed. Run: $0 install" >&2
    exit 1
  fi

  local display_value="${1:-$DEFAULT_DISPLAY}"
  echo "Launching ${APP_ID} with DISPLAY=${display_value} XDG_RUNTIME_DIR=${DEFAULT_RUNTIME_DIR}"
  setsid -f env DISPLAY="${display_value}" XDG_RUNTIME_DIR="${DEFAULT_RUNTIME_DIR}" flatpak run "$APP_ID"
}

status_app() {
  if have rg; then
    ps -ef | rg -i 'org.chromium.Chromium|chromium( |$)' || true
  else
    ps -ef | grep -Ei 'org\.chromium\.Chromium|chromium( |$)' || true
  fi
}

desktop_dir() {
  local dir=""

  if have xdg-user-dir; then
    dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  fi

  if [ -n "${dir}" ] && [ -d "${dir}" ]; then
    printf '%s\n' "${dir}"
    return 0
  fi

  if [ -d "${HOME}/Desktop" ]; then
    printf '%s\n' "${HOME}/Desktop"
    return 0
  fi

  if [ -d "${HOME}/桌面" ]; then
    printf '%s\n' "${HOME}/桌面"
    return 0
  fi

  printf '%s\n' "${HOME}/Desktop"
}

desktop_launcher() {
  local dir
  local file

  dir="$(desktop_dir)"
  mkdir -p "$dir"
  file="${dir}/Chromium.desktop"

  cat >"$file" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Chromium
Comment=Access the Internet
Exec=flatpak run org.chromium.Chromium %U
Icon=org.chromium.Chromium
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

  chmod +x "$file"
  echo "Desktop launcher created: $file"
}

case "${1:-}" in
  diagnose)
    diagnose
    ;;
  install)
    install_app
    ;;
  launch)
    launch_app "${2:-}"
    ;;
  status)
    status_app
    ;;
  desktop)
    desktop_launcher
    ;;
  *)
    usage
    exit 1
    ;;
esac
