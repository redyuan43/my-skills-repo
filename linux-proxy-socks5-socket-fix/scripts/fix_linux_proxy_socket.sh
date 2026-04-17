#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_PORT="${DEFAULT_PORT:-10808}"
NO_PROXY_VALUE="localhost,127.0.0.0/8,::1"
MARKER_BEGIN="# >>> linux-proxy-socks5-socket-fix >>>"
MARKER_END="# <<< linux-proxy-socks5-socket-fix <<<"
V2RAYN_CONFIG="${HOME}/.local/share/v2rayN/guiConfigs/guiNConfig.json"

usage() {
  cat <<EOF
Usage:
  bash linux-proxy-socks5-socket-fix/scripts/${SCRIPT_NAME} diagnose
  bash linux-proxy-socks5-socket-fix/scripts/${SCRIPT_NAME} status
  bash linux-proxy-socks5-socket-fix/scripts/${SCRIPT_NAME} apply [--port PORT]
  bash linux-proxy-socks5-socket-fix/scripts/${SCRIPT_NAME} print-exports [--port PORT] [--shell bash|zsh]
  bash linux-proxy-socks5-socket-fix/scripts/${SCRIPT_NAME} revert
EOF
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_port_from_v2rayn() {
  if [ ! -f "$V2RAYN_CONFIG" ]; then
    return 1
  fi
  python3 - "$V2RAYN_CONFIG" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    raise SystemExit(1)

port = None
for inbound in data.get("Inbounds", []) or []:
    if inbound.get("Protocol") == "socks" and inbound.get("LocalPort"):
        port = inbound.get("LocalPort")
        break

if port is None:
    sys.exit(1)
print(port)
PY
}

extract_port_from_proxy_value() {
  local value="$1"
  if [ -z "$value" ]; then
    return 1
  fi
  python3 - "$value" <<'PY'
import re
import sys

value = sys.argv[1]
m = re.search(r"127\.0\.0\.1:(\d+)", value)
if not m:
    raise SystemExit(1)
print(m.group(1))
PY
}

detect_proxy_port() {
  local value
  for value in \
    "${ALL_PROXY:-}" \
    "${all_proxy:-}" \
    "${HTTP_PROXY:-}" \
    "${http_proxy:-}" \
    "${HTTPS_PROXY:-}" \
    "${https_proxy:-}"
  do
    if extract_port_from_proxy_value "$value" >/dev/null 2>&1; then
      extract_port_from_proxy_value "$value"
      return 0
    fi
  done

  if detect_port_from_v2rayn >/dev/null 2>&1; then
    detect_port_from_v2rayn
    return 0
  fi

  printf '%s\n' "$DEFAULT_PORT"
}

managed_block() {
  local port="$1"
  cat <<EOF
${MARKER_BEGIN}
case "\${ALL_PROXY:-\${all_proxy:-}}" in
  socks://127.0.0.1:${port}|socks://127.0.0.1:${port}/|socks5://127.0.0.1:${port}|socks5://127.0.0.1:${port}/|"")
    export ALL_PROXY="socks5://127.0.0.1:${port}"
    export all_proxy="\$ALL_PROXY"
    ;;
esac

case "\${HTTP_PROXY:-\${http_proxy:-\${HTTPS_PROXY:-\${https_proxy:-}}}}" in
  http://127.0.0.1:${port}|http://127.0.0.1:${port}/|"")
    export HTTP_PROXY="http://127.0.0.1:${port}/"
    export http_proxy="\$HTTP_PROXY"
    export HTTPS_PROXY="http://127.0.0.1:${port}/"
    export https_proxy="\$HTTPS_PROXY"
    export NO_PROXY="\${NO_PROXY:-${NO_PROXY_VALUE}}"
    export no_proxy="\${no_proxy:-\$NO_PROXY}"
    ;;
esac
${MARKER_END}
EOF
}

rewrite_managed_block() {
  local file_path="$1"
  local port="$2"

  mkdir -p "$(dirname "$file_path")"
  touch "$file_path"

  python3 - "$file_path" "$MARKER_BEGIN" "$MARKER_END" "$(managed_block "$port")" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
marker_begin = sys.argv[2]
marker_end = sys.argv[3]
block = sys.argv[4]

text = path.read_text(encoding="utf-8")
lines = text.splitlines()

out = []
inside = False
for line in lines:
    if line.strip() == marker_begin:
        inside = True
        continue
    if line.strip() == marker_end:
        inside = False
        continue
    if not inside:
        out.append(line)

while out and out[-1] == "":
    out.pop()

if out:
    out.append("")
out.extend(block.splitlines())
out.append("")

path.write_text("\n".join(out), encoding="utf-8")
PY
}

remove_managed_block() {
  local file_path="$1"
  if [ ! -f "$file_path" ]; then
    return 0
  fi

  python3 - "$file_path" "$MARKER_BEGIN" "$MARKER_END" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
marker_begin = sys.argv[2]
marker_end = sys.argv[3]
text = path.read_text(encoding="utf-8")
lines = text.splitlines()

out = []
inside = False
for line in lines:
    if line.strip() == marker_begin:
        inside = True
        continue
    if line.strip() == marker_end:
        inside = False
        continue
    if not inside:
        out.append(line)

while out and out[-1] == "":
  out.pop()

path.write_text(("\n".join(out) + "\n") if out else "", encoding="utf-8")
PY
}

print_exports() {
  local port="$1"
  cat <<EOF
export ALL_PROXY="socks5://127.0.0.1:${port}"
export all_proxy="\$ALL_PROXY"
export HTTP_PROXY="http://127.0.0.1:${port}/"
export http_proxy="\$HTTP_PROXY"
export HTTPS_PROXY="http://127.0.0.1:${port}/"
export https_proxy="\$HTTPS_PROXY"
export NO_PROXY="${NO_PROXY_VALUE}"
export no_proxy="\$NO_PROXY"
EOF
}

show_proxy_env() {
  env | rg -i '^(all|http|https|no)_proxy=' | sort || true
}

show_status() {
  local port
  port="$(detect_proxy_port)"
  echo "[detected_port]"
  echo "$port"
  echo
  echo "[env]"
  show_proxy_env
  echo
  echo "[managed_rc_blocks]"
  for file_path in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    printf '%s: ' "$file_path"
    if [ -f "$file_path" ] && rg -F "$MARKER_BEGIN" "$file_path" >/dev/null 2>&1; then
      echo "present"
    else
      echo "absent"
    fi
  done
}

diagnose() {
  local port
  port="$(detect_proxy_port)"

  echo "[proxy_env]"
  show_proxy_env
  echo

  echo "[shell_rc_hits]"
  rg -n 'ALL_PROXY|all_proxy|HTTP_PROXY|http_proxy|HTTPS_PROXY|https_proxy|NO_PROXY|no_proxy|socks://|socks5://' \
    "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile" "${HOME}/.bash_profile" 2>/dev/null || true
  echo

  echo "[processes]"
  ps -ef | rg -i 'v2rayn|xray|clash|mihomo|sing-box' || true
  echo

  echo "[ports]"
  ss -lntp 2>/dev/null | rg '1080|10808|10809|7890|7897|20170|20171|3128|8080' || true
  echo

  echo "[gsettings]"
  if have_cmd gsettings; then
    gsettings get org.gnome.system.proxy mode 2>/dev/null || true
    gsettings get org.gnome.system.proxy.http host 2>/dev/null || true
    gsettings get org.gnome.system.proxy.http port 2>/dev/null || true
    gsettings get org.gnome.system.proxy.https host 2>/dev/null || true
    gsettings get org.gnome.system.proxy.https port 2>/dev/null || true
    gsettings get org.gnome.system.proxy.socks host 2>/dev/null || true
    gsettings get org.gnome.system.proxy.socks port 2>/dev/null || true
  else
    echo "gsettings not found"
  fi
  echo

  echo "[v2rayn]"
  if [ -f "$V2RAYN_CONFIG" ]; then
    echo "config=${V2RAYN_CONFIG}"
    echo "detected_port=${port}"
    rg -n '"SysProxyType"|"SystemProxyExceptions"|"Protocol"|"LocalPort"' "$V2RAYN_CONFIG" || true
  else
    echo "config not found: ${V2RAYN_CONFIG}"
  fi
  echo

  echo "[recommended_exports]"
  print_exports "$port"
}

apply_fix() {
  local port="$1"
  rewrite_managed_block "${HOME}/.bashrc" "$port"
  rewrite_managed_block "${HOME}/.zshrc" "$port"

  echo "[ok] Updated:"
  echo "  ${HOME}/.bashrc"
  echo "  ${HOME}/.zshrc"
  echo
  echo "[next]"
  echo "Open a new interactive shell, or run:"
  print_exports "$port"
}

revert_fix() {
  remove_managed_block "${HOME}/.bashrc"
  remove_managed_block "${HOME}/.zshrc"
  echo "[ok] Removed managed proxy blocks from:"
  echo "  ${HOME}/.bashrc"
  echo "  ${HOME}/.zshrc"
}

cmd="${1:-}"
if [ $# -gt 0 ]; then
  shift
fi

PORT_OVERRIDE=""
TARGET_SHELL="bash"

while [ $# -gt 0 ]; do
  case "$1" in
    --port)
      PORT_OVERRIDE="${2:-}"
      shift 2
      ;;
    --shell)
      TARGET_SHELL="${2:-bash}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[error] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$TARGET_SHELL" in
  bash|zsh)
    ;;
  *)
    echo "[error] Unsupported shell: ${TARGET_SHELL}" >&2
    exit 1
    ;;
esac

PORT="${PORT_OVERRIDE:-$(detect_proxy_port)}"

case "${cmd}" in
  diagnose)
    diagnose
    ;;
  status)
    show_status
    ;;
  apply)
    apply_fix "$PORT"
    ;;
  print-exports)
    print_exports "$PORT"
    ;;
  revert)
    revert_fix
    ;;
  *)
    usage
    exit 1
    ;;
esac
