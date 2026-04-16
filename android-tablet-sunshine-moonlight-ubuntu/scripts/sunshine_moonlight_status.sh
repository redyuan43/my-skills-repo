#!/usr/bin/env bash
set -euo pipefail

echo "== ADB =="
adb devices -l

echo
echo "== Android foreground app =="
adb shell dumpsys window | tr -d '\000' | rg 'mCurrentFocus|mFocusedApp' || true

echo
echo "== X11 displays =="
xrandr --query | sed -n '1,120p'

echo
echo "== Sunshine service =="
systemctl --user is-enabled sunshine 2>/dev/null || true
systemctl --user is-active sunshine 2>/dev/null || true

echo
echo "== Sunshine Web UI =="
http_code="$(curl -kSs -o /dev/null -w '%{http_code}' https://127.0.0.1:47990 || true)"
if [[ -n "${http_code}" && "${http_code}" != "000" ]]; then
  echo "Sunshine is reachable on https://127.0.0.1:47990"
else
  echo "Sunshine is not reachable on https://127.0.0.1:47990"
fi

echo
echo "== Recent Sunshine log =="
journalctl --user -u sunshine -n 40 --no-pager || true
