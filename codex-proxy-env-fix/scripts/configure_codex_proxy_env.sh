#!/usr/bin/env bash
set -euo pipefail

apply=0
proxy_url=""
codex_bin="${HOME}/.local/bin/siyuan"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
run_exec_test=0

usage() {
  cat <<'EOF'
Usage:
  configure_codex_proxy_env.sh [--apply] [--proxy-url URL] [--codex-bin PATH] [--exec-test]

Detects a local xray/v2rayN/clash/mihomo/sing-box proxy listener and writes
Codex proxy variables to ~/.codex/.env. Defaults to dry-run.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=1
      shift
      ;;
    --proxy-url)
      proxy_url="${2:-}"
      shift 2
      ;;
    --codex-bin)
      codex_bin="${2:-}"
      shift 2
      ;;
    --exec-test)
      run_exec_test=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

say() {
  printf '%s\n' "$*"
}

curl_head() {
  local proxy="$1"
  timeout 20 curl -fsSI -L --proxy "$proxy" --connect-timeout 8 \
    "https://chatgpt.com/backend-api/" >/tmp/codex-proxy-env-fix-curl.log 2>&1
}

curl_head_any_status() {
  local proxy="$1"
  timeout 20 curl -I -L --proxy "$proxy" --connect-timeout 8 \
    "https://chatgpt.com/backend-api/" >/tmp/codex-proxy-env-fix-curl.log 2>&1
}

candidate_ports() {
  {
    if command -v ss >/dev/null 2>&1; then
      ss -ltnp 2>/dev/null \
        | sed -nE 's/.*127\.0\.0\.1:([0-9]+).*/\1/p'
    fi
    printf '%s\n' 10808 10809 7897 7890 7891 1080 20171 3128 8080 18080
  } | awk '!seen[$0]++'
}

detect_proxy_url() {
  local port candidate
  for port in $(candidate_ports); do
    for candidate in "http://127.0.0.1:${port}" "socks5h://127.0.0.1:${port}"; do
      if curl_head_any_status "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  done
  return 1
}

if [[ -z "$proxy_url" ]]; then
  say "Detecting local proxy listener..."
  if ! proxy_url="$(detect_proxy_url)"; then
    say "No working proxy listener detected for https://chatgpt.com/backend-api/." >&2
    say "Inspect listeners with: ss -ltnp | grep -E ':(10808|7897|7890|1080)'." >&2
    exit 1
  fi
fi

env_path="${codex_home}/.env"
env_text="$(cat <<EOF
wss_proxy=${proxy_url}
https_proxy=${proxy_url}
http_proxy=${proxy_url}
all_proxy=${proxy_url}
WSS_PROXY=${proxy_url}
HTTPS_PROXY=${proxy_url}
HTTP_PROXY=${proxy_url}
ALL_PROXY=${proxy_url}
NO_PROXY=127.0.0.1,localhost,::1
no_proxy=127.0.0.1,localhost,::1
EOF
)"

say "Selected proxy: ${proxy_url}"
say "Target env file: ${env_path}"

if [[ "$apply" != "1" ]]; then
  say "Dry-run only. Re-run with --apply to write:"
  printf '%s\n' "$env_text"
  exit 0
fi

mkdir -p "$codex_home"
if [[ -f "$env_path" ]]; then
  cp -p "$env_path" "${env_path}.backup-$(date +%Y%m%d-%H%M%S)"
fi
printf '%s\n' "$env_text" >"$env_path"
chmod 600 "$env_path"
stat -c '%U %G %a %s %n' "$env_path" 2>/dev/null || ls -l "$env_path"

if [[ -x "$codex_bin" ]]; then
  say "Running codex doctor..."
  "$codex_bin" doctor || true
  if [[ "$run_exec_test" == "1" ]]; then
    say "Running minimal exec test..."
    timeout 120 "$codex_bin" exec --skip-git-repo-check --ephemeral "只回复 OK"
  fi
else
  say "Codex binary not executable: ${codex_bin}" >&2
fi
