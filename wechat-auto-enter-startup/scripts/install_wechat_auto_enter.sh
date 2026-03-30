#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_MAIN_SCRIPT="${SCRIPT_DIR}/wechat_auto_enter.sh"
SOURCE_AUTOSTART_WRAPPER="${SCRIPT_DIR}/wechat_auto_enter_autostart.sh"

DESKTOP_DIR="${DESKTOP_DIR:-${HOME}/Desktop}"
MAIN_SCRIPT_TARGET="${MAIN_SCRIPT_TARGET:-${DESKTOP_DIR}/wechat_auto_enter.sh}"
WRAPPER_TARGET="${WRAPPER_TARGET:-${HOME}/.local/bin/wechat_auto_enter_autostart.sh}"
AUTOSTART_DESKTOP_FILE="${AUTOSTART_DESKTOP_FILE:-${HOME}/.config/autostart/wechat-auto-enter.desktop}"
AUTOSTART_DELAY="${AUTOSTART_DELAY:-8}"
DEFAULT_MODE="${DEFAULT_MODE:-vision}"
INSTALL_AUTOSTART=1
RUN_NOW=0

usage() {
  cat <<'EOF'
Usage:
  install_wechat_auto_enter.sh [options]

Options:
  --desktop-dir DIR        Install the main runtime script under DIR. Default: ~/Desktop
  --main-script PATH       Override the installed main runtime script path
  --wrapper-script PATH    Override the installed autostart wrapper path
  --desktop-file PATH      Override the installed XDG autostart desktop file path
  --autostart-delay N      Delay seconds before autostart wrapper runs the main script. Default: 8
  --mode MODE              Default runtime mode: vision | key | click. Default: vision
  --no-autostart           Remove any existing autostart desktop entry instead of installing one
  --run-now                Run the installed main script once after installation
  -h, --help               Show this help
EOF
}

fail() {
  printf 'install_wechat_auto_enter.sh: %s\n' "$*" >&2
  exit 1
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[&|]/\\&/g'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --desktop-dir)
      DESKTOP_DIR="${2:-}"
      shift 2
      ;;
    --main-script)
      MAIN_SCRIPT_TARGET="${2:-}"
      shift 2
      ;;
    --wrapper-script)
      WRAPPER_TARGET="${2:-}"
      shift 2
      ;;
    --desktop-file)
      AUTOSTART_DESKTOP_FILE="${2:-}"
      shift 2
      ;;
    --autostart-delay)
      AUTOSTART_DELAY="${2:-}"
      shift 2
      ;;
    --mode)
      DEFAULT_MODE="${2:-}"
      shift 2
      ;;
    --no-autostart)
      INSTALL_AUTOSTART=0
      shift
      ;;
    --run-now)
      RUN_NOW=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -f "${SOURCE_MAIN_SCRIPT}" ]] || fail "missing source main script: ${SOURCE_MAIN_SCRIPT}"
[[ -f "${SOURCE_AUTOSTART_WRAPPER}" ]] || fail "missing source autostart wrapper: ${SOURCE_AUTOSTART_WRAPPER}"
[[ "${AUTOSTART_DELAY}" =~ ^[0-9]+$ ]] || fail "--autostart-delay must be a non-negative integer"
[[ "${DEFAULT_MODE}" == "vision" || "${DEFAULT_MODE}" == "key" || "${DEFAULT_MODE}" == "click" ]] || fail "--mode must be vision, key, or click"

mkdir -p "${DESKTOP_DIR}"
mkdir -p "$(dirname "${WRAPPER_TARGET}")"
mkdir -p "$(dirname "${AUTOSTART_DESKTOP_FILE}")"

MAIN_SCRIPT_TARGET_ESCAPED="$(escape_sed_replacement "${MAIN_SCRIPT_TARGET}")"
DEFAULT_MODE_ESCAPED="$(escape_sed_replacement "${DEFAULT_MODE}")"
AUTOSTART_DELAY_ESCAPED="$(escape_sed_replacement "${AUTOSTART_DELAY}")"

sed \
  -e "s|__DEFAULT_MODE__|${DEFAULT_MODE_ESCAPED}|g" \
  "${SOURCE_MAIN_SCRIPT}" > "${MAIN_SCRIPT_TARGET}"

sed \
  -e "s|__MAIN_SCRIPT__|${MAIN_SCRIPT_TARGET_ESCAPED}|g" \
  -e "s|__AUTOSTART_DELAY__|${AUTOSTART_DELAY_ESCAPED}|g" \
  "${SOURCE_AUTOSTART_WRAPPER}" > "${WRAPPER_TARGET}"

chmod +x "${MAIN_SCRIPT_TARGET}" "${WRAPPER_TARGET}"
bash -n "${MAIN_SCRIPT_TARGET}"
bash -n "${WRAPPER_TARGET}"

if (( INSTALL_AUTOSTART == 1 )); then
  cat > "${AUTOSTART_DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=WeChat Auto Enter
Name[zh_CN]=微信自动进入
Comment=Start WeChat and automatically click the Enter Weixin button after login
Comment[zh_CN]=登录桌面后自动启动微信并点击进入微信按钮
Exec=${WRAPPER_TARGET}
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
X-XFCE-Autostart-enabled=true
EOF
else
  rm -f "${AUTOSTART_DESKTOP_FILE}"
fi

printf 'Installed main script: %s\n' "${MAIN_SCRIPT_TARGET}"
printf 'Installed autostart wrapper: %s\n' "${WRAPPER_TARGET}"
if (( INSTALL_AUTOSTART == 1 )); then
  printf 'Installed XDG autostart entry: %s\n' "${AUTOSTART_DESKTOP_FILE}"
else
  printf 'Removed XDG autostart entry: %s\n' "${AUTOSTART_DESKTOP_FILE}"
fi
printf 'Default mode: %s\n' "${DEFAULT_MODE}"
printf 'Autostart delay: %s seconds\n' "${AUTOSTART_DELAY}"

if (( RUN_NOW == 1 )); then
  exec "${MAIN_SCRIPT_TARGET}"
fi
