#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
SYSTEMD_SRC_DIR="${REPO_ROOT}/systemd/user"
USER_SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE_NAME="my-skills-repo-update-skill.service"
TIMER_NAME="my-skills-repo-update-skill.timer"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Error: missing command: %s\n' "$1" >&2
    exit 1
  }
}

install_timer() {
  mkdir -p "${USER_SYSTEMD_DIR}"
  ln -sfn "${SYSTEMD_SRC_DIR}/${SERVICE_NAME}" "${USER_SYSTEMD_DIR}/${SERVICE_NAME}"
  ln -sfn "${SYSTEMD_SRC_DIR}/${TIMER_NAME}" "${USER_SYSTEMD_DIR}/${TIMER_NAME}"
  systemctl --user daemon-reload
  systemctl --user enable --now "${TIMER_NAME}"
  systemctl --user status "${TIMER_NAME}" --no-pager
}

uninstall_timer() {
  systemctl --user disable --now "${TIMER_NAME}" >/dev/null 2>&1 || true
  rm -f "${USER_SYSTEMD_DIR}/${SERVICE_NAME}" "${USER_SYSTEMD_DIR}/${TIMER_NAME}"
  systemctl --user daemon-reload
}

status_timer() {
  systemctl --user status "${TIMER_NAME}" --no-pager
  printf '\n'
  systemctl --user list-timers "${TIMER_NAME}" --no-pager
}

logs_timer() {
  journalctl --user -u "${SERVICE_NAME}" -n "${1:-50}" --no-pager
}

usage() {
  cat <<'EOF'
Usage:
  manage_update_skill_timer.sh install
  manage_update_skill_timer.sh uninstall
  manage_update_skill_timer.sh status
  manage_update_skill_timer.sh logs [LINES]
EOF
}

main() {
  need_cmd systemctl
  case "${1:-status}" in
    install)
      install_timer
      ;;
    uninstall)
      uninstall_timer
      ;;
    status)
      status_timer
      ;;
    logs)
      shift || true
      logs_timer "${1:-50}"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
