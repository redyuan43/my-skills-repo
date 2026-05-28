#!/usr/bin/env bash
set -euo pipefail

SAFE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
用法:
  selftest.sh --safe
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --safe) SAFE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "${SAFE}" -ne 1 ]]; then
  echo "此 selftest 只支持 --safe，避免启动 gateway 或写入 ~/.openclaw。" >&2
  exit 2
fi

for path in \
  "${SKILL_DIR}/SKILL.md" \
  "${SKILL_DIR}/assets/templates/openclaw.json" \
  "${SKILL_DIR}/assets/templates/wechat-linux.env.example"; do
  [[ -s "${path}" ]] || { echo "缺少文件: ${path}" >&2; exit 1; }
done

rg -q "__PYWXDUMP_ROOT__" "${SKILL_DIR}/assets/templates/openclaw.json"
rg -q "__GATEWAY_AUTH_TOKEN__" "${SKILL_DIR}/assets/templates/openclaw.json"
rg -q "__OPENAI_API_KEY__" "${SKILL_DIR}/assets/templates/wechat-linux.env.example"
rg -q "Never publish a real" "${SKILL_DIR}/SKILL.md"
rg -q "Do not keep placeholder values" "${SKILL_DIR}/SKILL.md"

echo "selftest passed: openclaw-wechat-linux-local-launcher safe checks"
