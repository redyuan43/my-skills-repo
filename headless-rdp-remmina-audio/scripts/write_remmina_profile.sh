#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: $0 <server[:port]> [username] [profile_name]" >&2
  exit 1
fi

server="$1"
username="${2:-$USER}"
profile_name="${3:-${server%%:*}}"

profile_dir="${HOME}/.local/share/remmina"
mkdir -p "${profile_dir}"

profile_path="${profile_dir}/${profile_name}.remmina"

cat > "${profile_path}" <<EOF
[remmina]
name=${profile_name}
protocol=RDP
server=${server}
username=${username}
ignore-tls-errors=1
sound=local
microphone=
resolution_mode=1
resolution_width=0
resolution_height=0
scale=1
colordepth=16
quality=2
disableclipboard=0
disable-smooth-scrolling=0
viewmode=1
window_maximize=1
viewonly=0
multimon=0
keyboard_grab=1
domain=
password=.
window_height=1080
window_width=1920
EOF

chmod 600 "${profile_path}"
echo "${profile_path}"
