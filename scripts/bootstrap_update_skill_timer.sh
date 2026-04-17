#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
MANAGE_SCRIPT="${SCRIPT_DIR}/manage_update_skill_timer.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Error: missing command: %s\n' "$1" >&2
    exit 1
  }
}

log() {
  printf '[bootstrap-update-skill-timer] %s\n' "$*"
}

update_repo() {
  if [ ! -d "${REPO_ROOT}/.git" ]; then
    printf 'Error: not a git repo: %s\n' "${REPO_ROOT}" >&2
    exit 1
  fi

  log "updating_repo=${REPO_ROOT}"
  git -C "${REPO_ROOT}" pull --rebase
}

install_timer() {
  log "installing_timer=true"
  bash "${MANAGE_SCRIPT}" install
}

show_status() {
  printf '\n'
  log "timer_status"
  bash "${MANAGE_SCRIPT}" status
}

usage() {
  cat <<'EOF'
Usage:
  bootstrap_update_skill_timer.sh
  bootstrap_update_skill_timer.sh --skip-update

Default behavior:
  1. git pull --rebase current repo
  2. install and enable user-level systemd timer
  3. print timer status
EOF
}

main() {
  need_cmd git
  need_cmd bash

  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --skip-update)
      install_timer
      show_status
      ;;
    "")
      update_repo
      install_timer
      show_status
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
