#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  connect_vnc.sh <host>
  connect_vnc.sh <host:display>
  connect_vnc.sh <host:port>

Examples:
  connect_vnc.sh 192.168.31.10
  connect_vnc.sh 192.168.31.10:1
  connect_vnc.sh 192.168.31.10:5901

Rules:
  - host only       -> defaults to :1
  - host:N (N<=99)  -> treated as display number
  - host:PORT       -> treated as TCP port
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

TARGET_MODE=""
TARGET_HOST=""
TARGET_VALUE=""

pick_viewer() {
  local candidate
  for candidate in xtigervncviewer vncviewer gvncviewer remmina; do
    if command -v "$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

target_from_input() {
  local raw="$1"
  local host
  local tail

  if [[ -z "$raw" ]]; then
    die "missing target"
  fi

  if [[ "$raw" =~ [[:space:]] ]]; then
    die "target must not contain spaces"
  fi

  if [[ "$raw" == *:* ]]; then
    host="${raw%:*}"
    tail="${raw##*:}"

    [[ -n "$host" ]] || die "missing host in target: $raw"
    [[ "$host" != *:* ]] || die "IPv6 addresses are not supported by this script: $raw"
    [[ "$tail" =~ ^[0-9]+$ ]] || die "suffix after ':' must be numeric: $raw"

    if (( tail <= 99 )); then
      TARGET_MODE="display"
      TARGET_HOST="$host"
      TARGET_VALUE="$tail"
    else
      TARGET_MODE="port"
      TARGET_HOST="$host"
      TARGET_VALUE="$tail"
    fi
    return 0
  fi

  TARGET_MODE="display"
  TARGET_HOST="$raw"
  TARGET_VALUE="1"
}

launch_viewer() {
  local viewer="$1"
  local mode="$2"
  local host="$3"
  local value="$4"

  case "$viewer" in
    xtigervncviewer|vncviewer|gvncviewer)
      if [[ "$mode" == "display" ]]; then
        exec "$viewer" "${host}:${value}"
      fi
      exec "$viewer" "${host}::${value}"
      ;;
    remmina)
      if [[ "$mode" == "display" ]]; then
        exec remmina -c "vnc://${host}:$((5900 + value))"
      fi
      exec remmina -c "vnc://${host}:${value}"
      ;;
    *)
      die "unsupported viewer selected: $viewer"
      ;;
  esac
}

main() {
  local raw_target="${1-}"
  local viewer
  local mode
  local host
  local value

  if [[ -z "$raw_target" ]] || [[ "$raw_target" == "-h" ]] || [[ "$raw_target" == "--help" ]]; then
    usage
    [[ -n "$raw_target" ]] || exit 1
    exit 0
  fi

  target_from_input "$raw_target"
  mode="$TARGET_MODE"
  host="$TARGET_HOST"
  value="$TARGET_VALUE"

  if ! viewer="$(pick_viewer)"; then
    cat >&2 <<'EOF'
Error: no supported VNC viewer found.

Install one of:
  sudo apt-get install -y tigervnc-viewer
  sudo apt-get install -y remmina
EOF
    exit 1
  fi

  echo "Using viewer: $viewer" >&2
  if [[ "$mode" == "display" ]]; then
    echo "Connecting to display: ${host}:${value}" >&2
  else
    echo "Connecting to port: ${host}:${value}" >&2
  fi

  launch_viewer "$viewer" "$mode" "$host" "$value"
}

main "$@"
