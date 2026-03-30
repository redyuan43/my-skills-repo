#!/usr/bin/env bash
set -euo pipefail

MAIN_SCRIPT="__MAIN_SCRIPT__"
LOG_FILE="/tmp/wechat-auto-enter-autostart.log"
SESSION_DELAY_SECONDS="${WECHAT_AUTOSTART_SESSION_DELAY_SECONDS:-__AUTOSTART_DELAY__}"

{
  printf '[wechat-auto-enter-autostart] %s starting\n' "$(date '+%F %T')"
  sleep "${SESSION_DELAY_SECONDS}"
  exec "${MAIN_SCRIPT}"
} >>"${LOG_FILE}" 2>&1
