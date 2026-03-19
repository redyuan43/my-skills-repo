#!/usr/bin/env bash
set -euo pipefail

target="/usr/lib/snapd/snap-confine"

if [[ ! -e "$target" ]]; then
  echo "Missing: $target" >&2
  exit 1
fi

echo "Before:"
stat -c '%U %G %a %n' "$target"
ls -l "$target"

sudo chown root:root "$target"
sudo chmod 4755 "$target"

echo
echo "After:"
stat -c '%U %G %a %n' "$target"
ls -l "$target"

echo
echo "Restarting snapd..."
sudo systemctl restart snapd

echo "Done."
