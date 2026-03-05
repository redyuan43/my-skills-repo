#!/usr/bin/env bash
set -euo pipefail

echo "== timestamp =="
date -Is

echo "== memory =="
free -h

echo "== top processes by RSS =="
ps aux --sort=-%mem | head -n 20

echo "== default target =="
systemctl get-default || true

echo "== critical service states =="
for s in ollama.service ssh.service NetworkManager.service; do
  printf "%s enabled=" "$s"
  systemctl is-enabled "$s" 2>/dev/null || printf "unknown"
  printf " active="
  systemctl is-active "$s" 2>/dev/null || printf "unknown"
  printf "\n"
done

echo "== failed units =="
systemctl --failed --no-pager || true
