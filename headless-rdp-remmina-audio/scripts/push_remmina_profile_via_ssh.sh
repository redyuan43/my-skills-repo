#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "Usage: $0 <client-ssh-target> <server[:port]> [username] [profile_name]" >&2
  exit 1
fi

client_target="$1"
server="$2"
username="${3:-$USER}"
default_profile_name="RDP_${server//:/_}"
profile_name="${4:-$default_profile_name}"

ssh "$client_target" "mkdir -p ~/.local/share/remmina"

ssh "$client_target" "cat > ~/.local/share/remmina/${profile_name}.remmina <<'EOF'
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
chmod 600 ~/.local/share/remmina/${profile_name}.remmina
printf '%s\n' ~/.local/share/remmina/${profile_name}.remmina"
