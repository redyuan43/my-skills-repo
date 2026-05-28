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
  echo "此 selftest 只支持 --safe，避免发送测试消息或安装 Codex hook。" >&2
  exit 2
fi

[[ -s "${SKILL_DIR}/SKILL.md" ]] || { echo "缺少 SKILL.md" >&2; exit 1; }
[[ -s "${SKILL_DIR}/agents/openai.yaml" ]] || { echo "缺少 agents/openai.yaml" >&2; exit 1; }

rg -q "check.sh --send-test" "${SKILL_DIR}/SKILL.md"
rg -q "It does not send files" "${SKILL_DIR}/SKILL.md"
rg -q "USER_ID@im.wechat" "${SKILL_DIR}/SKILL.md"
rg -q "WeClaw" "${SKILL_DIR}/SKILL.md"

echo "selftest passed: codex-wechat-hook safe checks"
