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
  echo "此 selftest 只支持 --safe，避免发送消息、安装依赖或修改 ptrace 配置。" >&2
  exit 2
fi

for path in \
  "${SKILL_DIR}/SKILL.md" \
  "${SKILL_DIR}/scripts/send_text_with_setup.sh" \
  "${SKILL_DIR}/scripts/send_text_with_setup.py"; do
  [[ -s "${path}" ]] || { echo "缺少文件: ${path}" >&2; exit 1; }
done

rg -q "allow-ptrace-toggle" "${SKILL_DIR}/SKILL.md"
rg -q "explicit user confirmation" "${SKILL_DIR}/SKILL.md"
bash -n "${SKILL_DIR}/scripts/send_text_with_setup.sh"
python3 -m py_compile "${SKILL_DIR}/scripts/send_text_with_setup.py"

echo "selftest passed: linux-wechat-send-bootstrap safe checks"
