#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  repair_remote_codex_over_ssh.sh <host> [--proxy-port PORT] [--exec-check]

Examples:
  repair_remote_codex_over_ssh.sh nx2
  repair_remote_codex_over_ssh.sh nx2 --proxy-port 10808
  repair_remote_codex_over_ssh.sh nx2 --exec-check

What it fixes:
  - codex only visible in interactive shells because it lives under nvm
  - remote shell missing proxy environment even though localhost proxy is running
  - ssh host "codex ..." fails while manual login + codex works

Notes:
  - if the remote host has neither direct outbound access nor a localhost proxy, the script will
    stop with a clear network-path error instead of hanging on repeated timeouts
  - --exec-check performs a real Codex request and will consume remote account tokens/quota
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 2
fi

host=""
proxy_port=""
exec_check=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --proxy-port)
      proxy_port="${2:-}"
      if [ -z "$proxy_port" ]; then
        echo "missing value for --proxy-port" >&2
        exit 2
      fi
      shift 2
      ;;
    --exec-check)
      exec_check=1
      shift
      ;;
    --*)
      echo "unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [ -n "$host" ]; then
        echo "host already provided: $host" >&2
        exit 2
      fi
      host="$1"
      shift
      ;;
  esac
done

if [ -z "$host" ]; then
  echo "host is required" >&2
  exit 2
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "required command not found: $1" >&2
    exit 127
  }
}

need_cmd ssh
need_cmd mktemp

log() {
  printf '[remote-codex-fix] %s\n' "$*"
}

warn() {
  printf '[remote-codex-fix][warn] %s\n' "$*" >&2
}

die() {
  printf '[remote-codex-fix][error] %s\n' "$*" >&2
  exit 1
}

run_ssh() {
  ssh -o BatchMode=yes "$host" "$@"
}

tmp_script="$(mktemp)"
cleanup() {
  rm -f "$tmp_script"
}
trap cleanup EXIT

cat >"$tmp_script" <<'REMOTE'
#!/usr/bin/env bash
set -euo pipefail

requested_proxy_port="${1:-}"

log() {
  printf '[remote-bootstrap] %s\n' "$*"
}

backup_if_needed() {
  local path="$1"
  local stamp="$2"
  if [ -f "$path" ]; then
    cp -p "$path" "${path}.bak.${stamp}"
  fi
}

write_if_changed() {
  local path="$1"
  local content="$2"
  if [ -f "$path" ] && [ "$(cat "$path")" = "$content" ]; then
    return 0
  fi
  printf '%s' "$content" >"$path"
}

append_block_if_missing() {
  local path="$1"
  local block="$2"
  if grep -Fq '.codex-shell-env' "$path" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$block" >>"$path"
}

ensure_bashrc_load_block() {
  local path="$1"
  local block="$2"
  if grep -Fq '.codex-shell-env' "$path" 2>/dev/null; then
    return 0
  fi

  python3 - "$path" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
block = """
# Load shared Codex/network CLI environment.
if [ -f "$HOME/.codex-shell-env" ]; then
    . "$HOME/.codex-shell-env"
fi
"""
marker = "case $- in\n"
idx = text.find(marker)
if idx == -1:
    path.write_text(block + "\n" + text)
else:
    path.write_text(text[:idx] + block + text[idx:])
PY
}

find_codex_bin() {
  local node_path latest
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
    node_path="$(nvm which current 2>/dev/null || true)"
    if [ -n "$node_path" ] && [ -x "$node_path" ] && [ -x "$(dirname "$node_path")/codex" ]; then
      printf '%s\n' "$(dirname "$node_path")/codex"
      return 0
    fi
  fi
  latest="$(find "$HOME/.nvm/versions/node" -maxdepth 3 -path '*/bin/codex' 2>/dev/null | sort -V | tail -1 || true)"
  if [ -n "$latest" ] && [ -x "$latest" ]; then
    printf '%s\n' "$latest"
    return 0
  fi
  command -v codex 2>/dev/null || true
}

curl_direct_ok() {
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
    curl -I -sS --max-time 6 https://api.openai.com/v1/models >/dev/null 2>&1
}

curl_http_proxy_ok() {
  local port="$1"
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
    HTTP_PROXY="http://127.0.0.1:${port}/" \
    HTTPS_PROXY="http://127.0.0.1:${port}/" \
    curl -I -sS --max-time 6 https://api.openai.com/v1/models >/dev/null 2>&1
}

curl_socks_proxy_ok() {
  local port="$1"
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
    ALL_PROXY="socks5h://127.0.0.1:${port}/" \
    curl -I -sS --max-time 6 https://api.openai.com/v1/models >/dev/null 2>&1
}

port_listens() {
  local port="$1"
  ss -ltn "( sport = :${port} )" 2>/dev/null | grep -q ":${port}"
}

detect_proxy_env() {
  local candidates=()
  local port http_proxy="" https_proxy="" all_proxy=""

  if [ -n "$requested_proxy_port" ]; then
    candidates+=("$requested_proxy_port")
  else
    candidates+=(10808 7890 7891 1080 8080)
  fi

  for port in "${candidates[@]}"; do
    if ! port_listens "$port"; then
      continue
    fi
    if curl_http_proxy_ok "$port"; then
      http_proxy="http://127.0.0.1:${port}/"
      https_proxy="$http_proxy"
    fi
    if curl_socks_proxy_ok "$port"; then
      all_proxy="socks5h://127.0.0.1:${port}/"
    fi
    if [ -n "$http_proxy" ] || [ -n "$all_proxy" ]; then
      printf '%s\n' "$http_proxy|$https_proxy|$all_proxy|$port"
      return 0
    fi
  done

  printf '|||'
}

stamp="$(date +%Y%m%d-%H%M%S)"
shell_env="$HOME/.codex-shell-env"
profile="$HOME/.profile"
bashrc="$HOME/.bashrc"
mkdir -p "$HOME/bin"

existing_http_proxy=""
existing_https_proxy=""
existing_all_proxy=""
if [ -f "$shell_env" ]; then
  IFS='|' read -r existing_http_proxy existing_https_proxy existing_all_proxy <<<"$(
    env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u NO_PROXY \
      bash -c '. "$1"; printf "%s|%s|%s\n" "${HTTP_PROXY-}" "${HTTPS_PROXY-}" "${ALL_PROXY-}"' _ "$shell_env" 2>/dev/null || true
  )"
fi

codex_bin="$(find_codex_bin || true)"
direct_network_ok=0
if curl_direct_ok; then
  direct_network_ok=1
fi

http_proxy="${existing_http_proxy:-}"
https_proxy="${existing_https_proxy:-}"
all_proxy="${existing_all_proxy:-}"
proxy_port_used=""
if [ "$direct_network_ok" -ne 1 ] && [ -z "$http_proxy" ] && [ -z "$all_proxy" ]; then
  IFS='|' read -r http_proxy https_proxy all_proxy proxy_port_used <<<"$(detect_proxy_env)"
fi

shell_env_content="# Shared Codex/network CLI environment.
# Managed by repair_remote_codex_over_ssh.sh.
"

if [ -n "$http_proxy" ]; then
  shell_env_content="${shell_env_content}
export HTTP_PROXY=\"\${HTTP_PROXY:-${http_proxy}}\"
export HTTPS_PROXY=\"\${HTTPS_PROXY:-${https_proxy}}\"
"
fi

if [ -n "$all_proxy" ]; then
  shell_env_content="${shell_env_content}
export ALL_PROXY=\"\${ALL_PROXY:-${all_proxy}}\"
"
fi

shell_env_content="${shell_env_content}
export NO_PROXY=\"\${NO_PROXY:-localhost,127.0.0.0/8,::1}\"

export NVM_DIR=\"\$HOME/.nvm\"
if [ -s \"\$NVM_DIR/nvm.sh\" ]; then
    . \"\$NVM_DIR/nvm.sh\"
fi

if [ -d \"\$HOME/bin\" ]; then
    case \":\$PATH:\" in
        *\":\$HOME/bin:\"*) ;;
        *) PATH=\"\$HOME/bin:\$PATH\" ;;
    esac
fi

if [ -d \"\$HOME/.local/bin\" ]; then
    case \":\$PATH:\" in
        *\":\$HOME/.local/bin:\"*) ;;
        *) PATH=\"\$HOME/.local/bin:\$PATH\" ;;
    esac
fi

if [ -d \"\$HOME/.opencode/bin\" ]; then
    case \":\$PATH:\" in
        *\":\$HOME/.opencode/bin:\"*) ;;
        *) PATH=\"\$HOME/.opencode/bin:\$PATH\" ;;
    esac
fi

export PATH
"

if [ -f "$shell_env" ]; then
  backup_if_needed "$shell_env" "$stamp"
fi
write_if_changed "$shell_env" "$shell_env_content"

if [ ! -f "$profile" ]; then
  : >"$profile"
fi
if [ ! -f "$bashrc" ]; then
  : >"$bashrc"
fi

backup_if_needed "$profile" "$stamp"
backup_if_needed "$bashrc" "$stamp"

append_block_if_missing "$profile" '
# Load shared Codex/network CLI environment.
if [ -f "$HOME/.codex-shell-env" ]; then
    . "$HOME/.codex-shell-env"
fi'

ensure_bashrc_load_block "$bashrc" '
# Load shared Codex/network CLI environment.
if [ -f "$HOME/.codex-shell-env" ]; then
    . "$HOME/.codex-shell-env"
fi'

wrapper_content='#!/usr/bin/env bash
set -euo pipefail

if [ -f "$HOME/.codex-shell-env" ]; then
    . "$HOME/.codex-shell-env"
fi

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    node_path="$(nvm which current 2>/dev/null || true)"
    if [ -n "$node_path" ] && [ -x "$node_path" ] && [ -x "$(dirname "$node_path")/codex" ]; then
        exec "$(dirname "$node_path")/codex" "$@"
    fi
fi

latest_codex="$(find "$HOME/.nvm/versions/node" -maxdepth 3 -path '"'"'*/bin/codex'"'"' 2>/dev/null | sort -V | tail -1)"
if [ -n "$latest_codex" ] && [ -x "$latest_codex" ]; then
    exec "$latest_codex" "$@"
fi

echo "codex binary not found under $HOME/.nvm/versions/node" >&2
exit 127
'

wrapper_tmp="$(mktemp)"
printf '%s' "$wrapper_content" >"$wrapper_tmp"
chmod 755 "$wrapper_tmp"

wrapper_target=""
if sudo -n true >/dev/null 2>&1; then
  sudo install -m 755 "$wrapper_tmp" /usr/local/bin/codex
  wrapper_target="/usr/local/bin/codex"
else
  install -m 755 "$wrapper_tmp" "$HOME/bin/codex"
  wrapper_target="$HOME/bin/codex"
fi
rm -f "$wrapper_tmp"

printf 'summary.host=%s\n' "$(hostname)"
printf 'summary.user=%s\n' "$(id -un)"
printf 'summary.codex_bin=%s\n' "${codex_bin:-}"
printf 'summary.direct_network_ok=%s\n' "$direct_network_ok"
printf 'summary.proxy_port=%s\n' "${proxy_port_used:-}"
printf 'summary.http_proxy=%s\n' "${http_proxy:-}"
printf 'summary.all_proxy=%s\n' "${all_proxy:-}"
printf 'summary.shell_env=%s\n' "$shell_env"
printf 'summary.wrapper=%s\n' "$wrapper_target"
REMOTE

log "probing current remote shell behavior"
run_ssh "echo remote-shell PATH=\$PATH; command -v codex || true"
run_ssh "bash -lc 'echo login-noninteractive PATH=\$PATH; command -v codex || true'"
run_ssh "bash -ic 'echo interactive PATH=\$PATH; command -v codex || true'" || true

log "applying remote bootstrap"
bootstrap_output="$(ssh -o BatchMode=yes "$host" bash -s -- "$proxy_port" <"$tmp_script")"
printf '%s\n' "$bootstrap_output"

direct_network_ok="$(printf '%s\n' "$bootstrap_output" | awk -F= '/^summary.direct_network_ok=/{print $2; exit}')"
detected_proxy_port="$(printf '%s\n' "$bootstrap_output" | awk -F= '/^summary.proxy_port=/{print $2; exit}')"
detected_http_proxy="$(printf '%s\n' "$bootstrap_output" | awk -F= '/^summary.http_proxy=/{print $2; exit}')"
detected_all_proxy="$(printf '%s\n' "$bootstrap_output" | awk -F= '/^summary.all_proxy=/{print $2; exit}')"
wrapper_target="$(printf '%s\n' "$bootstrap_output" | awk -F= '/^summary.wrapper=/{print $2; exit}')"

if [ "${direct_network_ok:-0}" != "1" ] && [ -z "${detected_http_proxy:-}" ] && [ -z "${detected_all_proxy:-}" ]; then
  die "remote host has no verified outbound path to OpenAI. No direct network and no working localhost proxy were found. Start a proxy on the remote host or pass --proxy-port <port>."
fi

if [ -n "${wrapper_target:-}" ] && [[ "$wrapper_target" == /home/*/bin/codex ]]; then
  warn "remote codex wrapper was installed under the remote user's home instead of /usr/local/bin because passwordless sudo was unavailable"
fi

if [ "${direct_network_ok:-0}" != "1" ] && [ -n "${detected_proxy_port:-}" ]; then
  log "using remote localhost proxy on port ${detected_proxy_port}"
fi

log "verifying codex visibility and proxy export"
run_ssh "codex --version"
run_ssh "bash -lc 'command -v codex; printf \"HTTP_PROXY=%s\nHTTPS_PROXY=%s\nALL_PROXY=%s\n\" \"\$HTTP_PROXY\" \"\$HTTPS_PROXY\" \"\$ALL_PROXY\"'"
run_ssh "bash -lc 'curl -I --max-time 8 https://api.openai.com/v1/models 2>&1 | sed -n \"1,20p\"'"

if [ "$exec_check" -eq 1 ]; then
  warn "--exec-check sends a real Codex request and consumes remote account quota/tokens"
  log "running minimal codex exec check"
  run_ssh "codex exec --skip-git-repo-check -C \$HOME 'Reply with exactly OK and nothing else.'"
fi

log "done"
