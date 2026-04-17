#!/usr/bin/env bash
set -euo pipefail

LMSTUDIO_HOME="${HOME}/.lmstudio"
LMSTUDIO_BIN="${HOME}/.local/bin/lmstudio"
LMSTUDIO_OPT_DIR="${HOME}/.local/opt/lmstudio"
LMSTUDIO_DESKTOP="${HOME}/.local/share/applications/lmstudio.desktop"

usage() {
  cat <<'EOF'
Usage:
  reconcile_lmstudio_gui.sh status
  reconcile_lmstudio_gui.sh repair [--prune-old]
  reconcile_lmstudio_gui.sh rewrite-desktop
EOF
}

detect_arch() {
  local machine
  machine="$(uname -m)"
  case "${machine}" in
    x86_64|amd64)
      printf 'x64\n'
      ;;
    aarch64|arm64)
      printf 'arm64\n'
      ;;
    *)
      printf 'Unsupported architecture: %s\n' "${machine}" >&2
      exit 1
      ;;
  esac
}

latest_llmster_path() {
  find "${LMSTUDIO_HOME}/llmster" -maxdepth 2 -type f -name llmster 2>/dev/null | sort -V | tail -n 1
}

latest_gui_url() {
  local arch="$1"
  curl -fsSLI -o /dev/null -w '%{url_effective}\n' "https://lmstudio.ai/download/latest/linux/${arch}?format=AppImage"
}

rewrite_desktop() {
  mkdir -p "$(dirname "${LMSTUDIO_DESKTOP}")" "$(dirname "${LMSTUDIO_BIN}")"
  cat > "${LMSTUDIO_DESKTOP}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=LM Studio
Comment=Discover, download, and run local LLMs
Exec=${LMSTUDIO_BIN} --no-sandbox %U
TryExec=${LMSTUDIO_BIN}
Terminal=false
Categories=Development;Utility;
StartupNotify=true
EOF
}

print_status() {
  local llmster_path resolved_link desktop_exec desktop_tryexec
  llmster_path="$(latest_llmster_path || true)"
  resolved_link="$(readlink -f "${LMSTUDIO_BIN}" 2>/dev/null || true)"
  desktop_exec="$(sed -n 's/^Exec=//p' "${LMSTUDIO_DESKTOP}" 2>/dev/null || true)"
  desktop_tryexec="$(sed -n 's/^TryExec=//p' "${LMSTUDIO_DESKTOP}" 2>/dev/null || true)"

  printf 'arch=%s\n' "$(detect_arch)"
  printf 'llmster=%s\n' "${llmster_path:-missing}"
  printf 'lmstudio_symlink=%s\n' "${resolved_link:-missing}"
  printf 'desktop_exec=%s\n' "${desktop_exec:-missing}"
  printf 'desktop_tryexec=%s\n' "${desktop_tryexec:-missing}"
  printf 'appimages:\n'
  find "${LMSTUDIO_OPT_DIR}" -maxdepth 1 -type f -name 'LM-Studio-*.AppImage' -printf '  %f\n' 2>/dev/null | sort -V
}

repair() {
  local prune_old=0 arch url filename target current

  while (($#)); do
    case "$1" in
      --prune-old)
        prune_old=1
        shift
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        exit 1
        ;;
    esac
  done

  arch="$(detect_arch)"
  mkdir -p "${LMSTUDIO_OPT_DIR}" "$(dirname "${LMSTUDIO_BIN}")"
  url="$(latest_gui_url "${arch}")"
  filename="$(basename "${url}")"
  target="${LMSTUDIO_OPT_DIR}/${filename}"

  if [[ ! -f "${target}" ]]; then
    curl -fL "${url}" -o "${target}"
  fi

  chmod +x "${target}"
  ln -sfn "${target}" "${LMSTUDIO_BIN}"
  rewrite_desktop

  if [[ "${prune_old}" == "1" ]]; then
    current="$(readlink -f "${LMSTUDIO_BIN}")"
    find "${LMSTUDIO_OPT_DIR}" -maxdepth 1 -type f -name 'LM-Studio-*.AppImage' ! -samefile "${current}" -delete
  fi

  print_status
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    status)
      shift
      print_status
      ;;
    repair)
      shift
      repair "$@"
      ;;
    rewrite-desktop)
      shift
      rewrite_desktop
      print_status
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
