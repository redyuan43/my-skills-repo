#!/usr/bin/env bash
set -euo pipefail

SHOW_STATUS=0
MINUTES=""
TIMEOUT_SECONDS=""
LOCK_DELAY=0

usage() {
  cat <<'EOF'
Usage:
  set_xfce_lock_screen_timeout.sh --status
  set_xfce_lock_screen_timeout.sh --minutes 60 [--lock-delay 0]
  set_xfce_lock_screen_timeout.sh --seconds 3600 [--lock-delay 0]

Options:
  --status              Show current XFCE screensaver and X11 timeout state
  --minutes N           Set idle timeout to N minutes
  --seconds N           Set idle timeout to N seconds
  --lock-delay N        Lock N seconds after screensaver activates (default: 0)
  -h, --help            Show this help

Notes:
  - Run this inside the active XFCE graphical session.
  - This script targets xfce4-screensaver + X11 xset.
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if ! need_cmd "$1"; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

current_cycle() {
  if ! need_cmd xset || [[ -z "${DISPLAY:-}" ]]; then
    printf '300\n'
    return 0
  fi

  xset q 2>/dev/null | awk '
    /Screen Saver:/ { in_section=1; next }
    in_section && /timeout:/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "cycle:") {
          print $(i + 1)
          exit
        }
      }
    }
  ' | awk 'NF { print; found=1 } END { if (!found) print 300 }'
}

xfconf_set() {
  local type="$1"
  local path="$2"
  local value="$3"

  xfconf-query -c xfce4-screensaver -p "$path" -s "$value" 2>/dev/null \
    || xfconf-query -c xfce4-screensaver -n -t "$type" -p "$path" -s "$value"
}

print_components() {
  local any=0
  local pattern

  for pattern in xfce4-screensaver light-locker xscreensaver xfce4-power-manager; do
    if pgrep -af "$pattern" >/dev/null 2>&1; then
      pgrep -af "$pattern"
      any=1
    fi
  done

  if (( ! any )); then
    printf 'No known XFCE lock components found in process list.\n'
  fi
}

screensaver_running() {
  pgrep -af "xfce4-screensaver" >/dev/null 2>&1
}

show_status() {
  printf 'desktop=%s\n' "${XDG_CURRENT_DESKTOP:-<unset>}"
  printf 'session=%s\n' "${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-<unset>}}"
  printf 'display=%s\n' "${DISPLAY:-<unset>}"
  printf 'dbus=%s\n' "${DBUS_SESSION_BUS_ADDRESS:-<unset>}"
  printf '\n[components]\n'
  print_components

  printf '\n[xfconf]\n'
  if need_cmd xfconf-query; then
    xfconf-query -c xfce4-screensaver -lv 2>/dev/null || printf 'xfce4-screensaver channel not initialized yet.\n'
  else
    printf 'xfconf-query not found.\n'
  fi

  printf '\n[xset]\n'
  if need_cmd xset && [[ -n "${DISPLAY:-}" ]]; then
    xset q 2>/dev/null | sed -n '/Screen Saver:/,/Colors:/p' || printf 'Unable to query xset.\n'
  else
    printf 'xset unavailable or DISPLAY is not set.\n'
  fi
}

apply_timeout() {
  local seconds="$1"
  local cycle="$2"

  require_cmd xfconf-query
  require_cmd xset

  if [[ -z "${DISPLAY:-}" ]]; then
    printf 'DISPLAY is not set. Run this inside the active XFCE graphical session.\n' >&2
    exit 1
  fi

  if ! screensaver_running; then
    printf 'xfce4-screensaver is not running. This skill does not cover other lock managers.\n' >&2
    exit 1
  fi

  xfconf_set bool /saver/enabled true
  xfconf_set bool /saver/idle-activation/enabled true
  xfconf_set int /saver/idle-activation/delay "$seconds"
  xfconf_set bool /lock/enabled true
  xfconf_set bool /lock/saver-activation/enabled true
  xfconf_set int /lock/saver-activation/delay "$LOCK_DELAY"

  xset s "$seconds" "$cycle"

  printf 'Applied idle timeout: %s seconds\n' "$seconds"
  printf 'Applied lock delay: %s seconds\n' "$LOCK_DELAY"
  printf 'Applied xset cycle: %s seconds\n' "$cycle"
}

while (($#)); do
  case "$1" in
    --status)
      SHOW_STATUS=1
      shift
      ;;
    --minutes)
      MINUTES="${2:-}"
      shift 2
      ;;
    --seconds)
      TIMEOUT_SECONDS="${2:-}"
      shift 2
      ;;
    --lock-delay)
      LOCK_DELAY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if (( SHOW_STATUS )); then
  show_status
  exit 0
fi

if [[ -n "$MINUTES" && -n "$TIMEOUT_SECONDS" ]]; then
  printf 'Use either --minutes or --seconds, not both.\n' >&2
  exit 1
fi

if [[ -n "$MINUTES" ]]; then
  if ! is_integer "$MINUTES"; then
    printf 'Minutes must be a non-negative integer.\n' >&2
    exit 1
  fi
  TIMEOUT_SECONDS="$((MINUTES * 60))"
fi

if [[ -z "$TIMEOUT_SECONDS" ]]; then
  usage >&2
  exit 1
fi

if ! is_integer "$TIMEOUT_SECONDS" || ! is_integer "$LOCK_DELAY"; then
  printf 'Seconds and lock delay must be non-negative integers.\n' >&2
  exit 1
fi

apply_timeout "$TIMEOUT_SECONDS" "$(current_cycle)"
printf '\n[verification]\n'
show_status
