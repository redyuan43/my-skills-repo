#!/bin/sh

set -eu

export DISPLAY="${DISPLAY:-:1}"

kill_exact() {
  name="$1"
  while read -r pid; do
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null || true
  done <<EOF
$(ps -C "$name" -o pid= 2>/dev/null || true)
EOF
}

kill_match() {
  pattern="$1"
  ps -eo pid=,args= | awk -v pat="$pattern" '$0 ~ pat { print $1 }' | while read -r pid; do
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null || true
  done
}

sleep 4

xset s 0 0 || true
xset s off || true
xset -dpms || true
xset s noblank || true

kill_exact xfce4-screensaver-dialog
kill_exact xfce4-screensaver
kill_exact xiccd
kill_match "/usr/share/system-config-printer/applet.py"

sleep 6
kill_exact xfce4-screensaver-dialog
kill_exact xfce4-screensaver
kill_exact xiccd
kill_match "/usr/share/system-config-printer/applet.py"
