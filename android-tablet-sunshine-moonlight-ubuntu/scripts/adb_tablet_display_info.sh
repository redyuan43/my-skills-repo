#!/usr/bin/env bash
set -euo pipefail

echo "== ADB Devices =="
adb devices -l

serial="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
if [[ -z "${serial}" ]]; then
  echo
  echo "No authorized Android device found."
  exit 1
fi

echo
echo "== wm size =="
adb -s "${serial}" shell wm size

echo
echo "== wm density =="
adb -s "${serial}" shell wm density

echo
echo "== display summary =="
adb -s "${serial}" shell dumpsys display \
  | tr -d '\000' \
  | sed -n '1,220p' \
  | rg -n "mViewports=|DisplayViewport|deviceWidth|deviceHeight|Frame|orientation|density"
