#!/usr/bin/env bash
set -euo pipefail

mode="${1:-status}"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "缺少命令: $1" >&2
        exit 1
    fi
}

require_cmd tailscale
require_cmd python3

get_service_state() {
    local field="$1"
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "unknown"
        return
    fi

    if [[ "$field" == "enabled" ]]; then
        systemctl is-enabled tailscaled 2>/dev/null || true
        return
    fi

    if [[ "$field" == "active" ]]; then
        systemctl is-active tailscaled 2>/dev/null || true
        return
    fi

    echo "unknown"
}

print_status() {
    local enabled active status_json
    enabled="$(get_service_state enabled)"
    active="$(get_service_state active)"
    status_json="$(tailscale status --json 2>/dev/null || true)"

    STATUS_JSON="$status_json" python3 - "$enabled" "$active" <<'PY'
import json
import os
import sys

enabled = sys.argv[1] or "unknown"
active = sys.argv[2] or "unknown"
raw = os.environ.get("STATUS_JSON", "").strip()

if not raw:
    print("Tailscale 状态: 无法读取 status --json")
    print(f"tailscaled enabled: {enabled}")
    print(f"tailscaled active: {active}")
    print("结论: 需要排查 tailscaled 是否启动，或当前用户是否有权限访问本地 daemon。")
    sys.exit(0)

data = json.loads(raw)
self_node = data.get("Self") or {}
tailnet = (data.get("CurrentTailnet") or {}).get("Name") or "-"
auth_url = data.get("AuthURL") or ""
backend = data.get("BackendState") or "-"
online = self_node.get("Online")
hostname = self_node.get("HostName") or "-"
ipv4 = (self_node.get("TailscaleIPs") or ["-"])[0]
key_expiry = self_node.get("KeyExpiry") or "-"

needs_login = bool(auth_url) or backend in {"NeedsLogin", "NoState", "LoggedOut"}

print(f"tailscaled enabled: {enabled}")
print(f"tailscaled active: {active}")
print(f"BackendState: {backend}")
print(f"Tailnet: {tailnet}")
print(f"HostName: {hostname}")
print(f"Tailscale IPv4: {ipv4}")
print(f"Online: {online}")
print(f"KeyExpiry: {key_expiry}")

if auth_url:
    print(f"AuthURL: {auth_url}")

if needs_login:
    print("结论: 需要重新登录 Tailscale。")
else:
    print("结论: 当前无需重新登录 Tailscale；正常重启后通常会自动恢复连接。")
PY
}

run_login() {
    local output
    echo "开始触发 Tailscale 登录流程..."
    set +e
    output="$(sudo tailscale up 2>&1)"
    local rc=$?
    set -e

    echo "$output"

    if [[ $rc -eq 0 ]]; then
        echo "Tailscale 登录或状态恢复已完成。"
        return
    fi

    if grep -q 'https://login.tailscale.com/' <<<"$output"; then
        echo "上面已经输出授权链接。请在浏览器中完成登录后，再重新执行本脚本确认状态。"
        return
    fi

    echo "未能自动完成登录。请检查 sudo 权限、网络连通性和 Tailscale 账号状态。" >&2
    exit "$rc"
}

case "$mode" in
    status)
        print_status
        ;;
    login)
        run_login
        ;;
    *)
        echo "用法: $0 [status|login]" >&2
        exit 1
        ;;
esac
