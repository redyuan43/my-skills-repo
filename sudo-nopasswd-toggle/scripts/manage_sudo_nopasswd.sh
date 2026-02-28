#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  manage_sudo_nopasswd.sh <enable|disable|status> [--user USER] [--password-stdin]

Options:
  --user USER         Target local account. Defaults to the current user.
  --password-stdin    Read one sudo password line from stdin, validate with sudo -S -v,
                      then reuse the cached sudo credential for the remaining commands.
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_user() {
  local target="$1"

  [[ "$target" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || die "invalid user name: $target"
  id "$target" >/dev/null 2>&1 || die "user does not exist: $target"
}

run_sudo() {
  sudo -n "$@"
}

auth_sudo() {
  if sudo -n true 2>/dev/null; then
    return 0
  fi

  if [[ "$PASSWORD_STDIN" -eq 1 ]]; then
    local sudo_password
    IFS= read -r sudo_password || die "expected sudo password on stdin"
    printf '%s\n' "$sudo_password" | sudo -S -v >/dev/null
    return 0
  fi

  if [[ -t 0 && -t 1 ]]; then
    sudo -v
    return 0
  fi

  die "sudo needs NOPASSWD, a cached credential, an interactive terminal, or --password-stdin"
}

write_rule() {
  local tmp_file
  tmp_file="$(mktemp)"
  trap 'rm -f "$tmp_file"' RETURN

  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$TARGET_USER" >"$tmp_file"
  run_sudo visudo -cf "$tmp_file" >/dev/null
  run_sudo install -m 440 -o root -g root "$tmp_file" "$TARGET_FILE"
  run_sudo visudo -c >/dev/null

  printf 'enabled: %s\n' "$TARGET_FILE"
}

remove_rule() {
  if run_sudo test -e "$TARGET_FILE"; then
    run_sudo rm -f "$TARGET_FILE"
    run_sudo visudo -c >/dev/null
    printf 'disabled: %s\n' "$TARGET_FILE"
  else
    printf 'already disabled: %s\n' "$TARGET_FILE"
  fi
}

show_status() {
  if run_sudo test -e "$TARGET_FILE"; then
    printf 'status: enabled\n'
    printf 'file: %s\n' "$TARGET_FILE"
    printf 'rule:\n'
    run_sudo cat "$TARGET_FILE"
  else
    printf 'status: disabled\n'
    printf 'file: %s\n' "$TARGET_FILE"
  fi
}

ACTION="${1:-}"
[[ -n "$ACTION" ]] || {
  usage
  exit 1
}
shift

TARGET_USER="$(whoami)"
PASSWORD_STDIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      [[ $# -ge 2 ]] || die "--user requires a value"
      TARGET_USER="$2"
      shift 2
      ;;
    --password-stdin)
      PASSWORD_STDIN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

case "$ACTION" in
  enable|disable|status)
    ;;
  *)
    die "unknown action: $ACTION"
    ;;
esac

require_user "$TARGET_USER"
TARGET_FILE="/etc/sudoers.d/90-${TARGET_USER}-nopasswd"

auth_sudo

case "$ACTION" in
  enable)
    write_rule
    ;;
  disable)
    remove_rule
    ;;
  status)
    show_status
    ;;
esac
